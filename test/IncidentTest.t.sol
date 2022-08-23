// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./utils/ContractSetupTest.sol";

import "src/interfaces/IPriorityPool.sol";

import "src/voting/incidentReport/IncidentReportParameters.sol";
import "src/voting/incidentReport/IncidentReportEventError.sol";

contract IncidentTest is
    ContractSetupBaseTest,
    IncidentReportParameters,
    IncidentReportEventError
{
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant PAYOUT = 1000e6;

    address internal joePool;
    address internal ptpPool;
    address internal gmxPool;

    MockERC20 joe;
    MockERC20 ptp;
    MockERC20 gmx;

    function setUp() public {
        setUpContracts();

        joe = new MockERC20("JoeToken", "JOE", 18);
        ptp = new MockERC20("Platypus", "PTP", 18);
        gmx = new MockERC20("GMXToken", "GMX", 18);

        joePool = priorityPoolFactory.deployPool(
            "TraderJoe",
            address(joe),
            CAPACITY_1,
            PREMIUMRATIO_1
        );

        ptpPool = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            CAPACITY_2,
            PREMIUMRATIO_2
        );

        gmxPool = priorityPoolFactory.deployPool(
            "GMX",
            address(gmx),
            CAPACITY_3,
            PREMIUMRATIO_3
        );
    }

    function testReport() public {
        /// @notice Should not start a report without enough DEG balance
        vm.warp(0);
        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        incidentReport.report(1, PAYOUT);

        /// @notice Should be able to start a report with enough DEG
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.warp(0);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit ReportCreated(1, 1, 0, CHARLIE, PAYOUT);
        incidentReport.report(1, PAYOUT);

        /// @notice Check the new report record
        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.poolId, 1);
        assertEq(report.reporter, CHARLIE);
        assertEq(report.reportTimestamp, 0);
        assertEq(report.status, PENDING_STATUS);
        assertEq(report.payout, PAYOUT);

        /// @notice Check the DEG balance after starting the report
        assertEq(deg.balanceOf(CHARLIE), 0);

        /// @notice Check the report counter after starting the report
        assertEq(incidentReport.reportCounter(), 1);

        /// @notice Check the total reports record of a pool
        assertEq(incidentReport.poolReports(1, 0), 1);
    }

    function _report() internal {
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.warp(0);
        vm.prank(CHARLIE);
        incidentReport.report(1, PAYOUT);
    }

    function testCloseReport() public {
        _report();

        /// @notice Should not be able to close a report by non-owner
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        incidentReport.closeReport(1);

        /// @notice Should not be able to close a report after pending period
        vm.warp(PENDING_PERIOD + 1);
        vm.expectRevert(IncidentReport__WrongPeriod.selector);
        incidentReport.closeReport(1);

        /// @notice Should be able to close a report by the owner
        vm.warp(PENDING_PERIOD);
        vm.expectEmit(false, false, false, true);
        emit ReportClosed(1, PENDING_PERIOD);
        incidentReport.closeReport(1);

        /// @notice Check the closed report record
        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.status, CLOSE_STATUS);
    }

    function testStartVoting() public {
        _report();

        /// @notice Should not be ablt to close a report after starting the vote
        vm.warp(PENDING_PERIOD + 1);
        incidentReport.startVoting(1);
        vm.warp(PENDING_PERIOD);
        vm.expectRevert(IncidentReport__WrongStatus.selector);
        incidentReport.closeReport(1);
    }
}
