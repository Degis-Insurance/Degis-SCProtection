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

    uint256 internal constant VOTE_FOR = 1;
    uint256 internal constant VOTE_AGAINST = 2;
    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant REPORT_TIME = 0;
    uint256 internal constant VOTE_TIME = PENDING_PERIOD;
    uint256 internal constant SETTLE_TIME = PENDING_PERIOD + VOTING_PERIOD;

    IPriorityPool internal joePool;
    IPriorityPool internal ptpPool;
    IPriorityPool internal gmxPool;

    MockERC20 internal joe;
    MockERC20 internal ptp;
    MockERC20 internal gmx;

    function setUp() public {
        setUpContracts();

        joe = new MockERC20("JoeToken", "JOE", 18);
        ptp = new MockERC20("Platypus", "PTP", 18);
        gmx = new MockERC20("GMXToken", "GMX", 18);

        joePool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "TraderJoe",
                address(joe),
                CAPACITY_1,
                PREMIUMRATIO_1
            )
        );

        ptpPool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "Platypus",
                address(ptp),
                CAPACITY_2,
                PREMIUMRATIO_2
            )
        );

        gmxPool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "GMX",
                address(gmx),
                CAPACITY_3,
                PREMIUMRATIO_3
            )
        );
    }

    function testReport() public {
        /// @notice Should not start a report without enough DEG balance
        vm.warp(REPORT_TIME);
        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        incidentReport.report(1, PAYOUT);

        /// @notice Should be able to start a report with enough DEG
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.warp(REPORT_TIME);
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
        vm.warp(REPORT_TIME);
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
        vm.warp(PENDING_PERIOD);
        vm.expectRevert(IncidentReport__WrongPeriod.selector);
        incidentReport.closeReport(1);

        /// @notice Should be able to close a report by the owner
        vm.warp(PENDING_PERIOD - 1);
        vm.expectEmit(false, false, false, true);
        emit ReportClosed(1, PENDING_PERIOD - 1);
        incidentReport.closeReport(1);

        /// @notice Check the closed report record
        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.status, CLOSE_STATUS);
    }

    function testStartVoting() public {
        /// @notice Start a report
        _report();

        /// @notice Should not be able to start a voting before pending period ends
        vm.warp(PENDING_PERIOD - 1);
        vm.expectRevert(IncidentReport__WrongPeriod.selector);
        incidentReport.startVoting(1);

        /// @notice Should be able to start a voting after pending period
        vm.warp(PENDING_PERIOD);
        incidentReport.startVoting(1);

        /// @notice Should be able to check the record
        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.status, VOTING_STATUS);
        assertEq(report.voteTimestamp, PENDING_PERIOD);

        /// @notice Should pause the priority pool and protection pool
        assertTrue(joePool.paused());
        assertTrue(protectionPool.paused());

        /// @notice Should not be able to start a voting with VOTING_STATUS
        vm.expectRevert(IncidentReport__WrongStatus.selector);
        incidentReport.startVoting(1);

        /// @notice Should not be able to close a report after starting the vote
        vm.warp(PENDING_PERIOD);
        vm.expectRevert(IncidentReport__WrongStatus.selector);
        incidentReport.closeReport(1);
    }

    function _startVoting() internal {
        vm.warp(VOTE_TIME);
        incidentReport.startVoting(1);
    }

    function testVote() public {
        /// @notice Start a report and start voting
        _report();
        _startVoting();

        /// @notice Preparations
        vm.startPrank(ALICE);

        /// @notice Should not be able to vote for without veDEG
        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(IncidentReport__NotEnoughVeDEG.selector);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);

        /// @notice Should not be able to vote against without veDEG
        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(IncidentReport__NotEnoughVeDEG.selector);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        /// @notice Should not be able to vote with a wrong choice
        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(IncidentReport__WrongChoice.selector);
        incidentReport.vote(1, 3, VOTE_AMOUNT);

        /// @notice Should not be able to vote with zero amount
        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(IncidentReport__ZeroAmount.selector);
        incidentReport.vote(1, VOTE_FOR, 0);

        /// @notice Should be able to vote with veDEG
        veDEG.mint(ALICE, VOTE_AMOUNT);
        vm.warp(VOTE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ReportVoted(1, ALICE, VOTE_FOR, VOTE_AMOUNT);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);

        /// @notice Should be able to check the record
        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.numFor, VOTE_AMOUNT);
        assertEq(report.numAgainst, 0);

        IncidentReport.UserVote memory userVote = incidentReport.getUserVote(
            ALICE,
            1
        );
        assertEq(userVote.choice, VOTE_FOR);
        assertEq(userVote.amount, VOTE_AMOUNT);

        IncidentReport.TempResult memory temp = incidentReport.getTempResult(1);
        assertEq(temp.result, 0);
        assertFalse(temp.hasChanged);

        /// @notice Should not be able to vote with both sides choices
        veDEG.mint(ALICE, VOTE_AMOUNT);
        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(IncidentReport__ChooseBothSides.selector);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        /// @notice Stop sending txs from Alice
        vm.stopPrank();

        /// @notice Should be able to vote from another user
        veDEG.mint(BOB, VOTE_AMOUNT);
        vm.prank(BOB);
        vm.warp(VOTE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ReportVoted(1, BOB, VOTE_AGAINST, VOTE_AMOUNT);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);
    }

    function testVoteFuzz(uint256 _choice) public {
        /// @notice Start a report and start voting
        _report();
        _startVoting();

        /// @notice Should not be able to vote with a wrong choice
        vm.prank(ALICE);
        vm.warp(VOTE_TIME + 1);
        vm.assume(_choice != 1 && _choice != 2);
        vm.expectRevert(IncidentReport__WrongChoice.selector);
        incidentReport.vote(1, _choice, VOTE_AMOUNT);
    }

    function testSettle() public {
        /// @notice Start a report and start voting
        _report();
        _startVoting();

        /// @notice Preparations
        veDEG.mint(ALICE, VOTE_AMOUNT * 2);
        veDEG.mint(BOB, VOTE_AMOUNT * 2);

        vm.prank(ALICE);
        vm.warp(PENDING_PERIOD + 1);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);

        vm.prank(BOB);
        vm.warp(PENDING_PERIOD + 1);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        /// @notice Take the evm snapshot for test
        uint256 snapshot_1 = vm.snapshot();

        // ---------------------------------------------------------- //
        // * Should not be able to settle before voting period ends * //
        // ---------------------------------------------------------- //

        vm.warp(SETTLE_TIME - 1);
        vm.expectRevert(IncidentReport__WrongPeriod.selector);
        incidentReport.settle(1);

        // ---------------------------------------------------------- //
        // * Should be able to settle with TIED & no extending * //
        // ---------------------------------------------------------- //

        vm.warp(SETTLE_TIME);
        vm.expectEmit(false, false, false, true);
        emit ReportSettled(1, TIED_RESULT);
        incidentReport.settle(1);

        /// @notice Should be able to check the record
        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.status, SETTLED_STATUS);
        assertEq(report.result, TIED_RESULT);

        // ---------------------------------------------------------- //
        // * Should be able to settle with REJECT & no extending * //
        // ---------------------------------------------------------- //

        /// @notice Revert to the previous snapshot and have a new snapshot
        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        /// @notice Bob vote against, making the result to REJECT
        vm.prank(BOB);
        vm.warp(VOTE_TIME + 1);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        /// @notice Settle the voting
        vm.warp(SETTLE_TIME);
        vm.expectEmit(false, false, false, true);
        emit ReportSettled(1, REJECT_RESULT);
        incidentReport.settle(1);

        /// @notice Should be able to check the record
        report = incidentReport.getReport(1);
        assertEq(report.status, SETTLED_STATUS);
        assertEq(report.result, REJECT_RESULT);

        /// @notice Should unpause the priority pool and protection pool
        assertFalse(joePool.paused());
        assertFalse(protectionPool.paused());

        // ---------------------------------------------------------- //
        // * Should be able to settle with PASS & no extending * //
        // ---------------------------------------------------------- //

        /// @notice Revert to the previous snapshot and have a new snapshot
        vm.revertTo(snapshot_2);
        uint256 snapshot_3 = vm.snapshot();

        /// @notice Alice vote for, making the result PASS
        vm.prank(ALICE);
        vm.warp(VOTE_TIME + 1);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);

        /// @notice Settle the voting
        vm.warp(SETTLE_TIME);
        vm.expectEmit(false, false, false, true);
        emit ReportSettled(1, PASS_RESULT);
        incidentReport.settle(1);

        /// @notice Should be able to check the record
        report = incidentReport.getReport(1);
        assertEq(report.status, SETTLED_STATUS);
        assertEq(report.result, PASS_RESULT);

        /// @notice Should unpause the priority pool and protection pool
        assertFalse(joePool.paused());
        assertFalse(protectionPool.paused());

        // ---------------------------------------------------------- //
        // * Should be able to settle with FAILED * //
        // ---------------------------------------------------------- //

        vm.revertTo(snapshot_3);

        veDEG.mint(address(this), 10000 ether);

        vm.warp(SETTLE_TIME);
        vm.expectEmit(false, false, false, true);
        emit ReportFailed(1);
        incidentReport.settle(1);

        /// @notice Should be able to check the record
        report = incidentReport.getReport(1);
        assertEq(report.status, SETTLED_STATUS);
        assertEq(report.result, FAILED_RESULT);

        /// @notice Should unpause the priority pool and protection pool
        assertFalse(joePool.paused());
        assertFalse(protectionPool.paused());
    }

    function testSettleWithExtendingRound() public {
        /// @notice Start a report and start voting
        _report();
        _startVoting();

        /// @notice Preparations
        veDEG.mint(ALICE, VOTE_AMOUNT * 2);
        veDEG.mint(BOB, VOTE_AMOUNT * 2);

        vm.prank(ALICE);
        vm.warp(SETTLE_TIME - 2);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);

        vm.prank(BOB);
        vm.warp(SETTLE_TIME - 1);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        IncidentReport.Report memory report = incidentReport.getReport(1);
        uint256 currentRound = report.round;

        /// @notice Should be able to extend the round
        vm.warp(SETTLE_TIME);
        vm.expectEmit(false, false, false, true);
        emit ReportExtended(1, currentRound + 1);
        incidentReport.settle(1);
    }
}
