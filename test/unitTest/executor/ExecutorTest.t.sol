// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "test/utils/ContractSetupBaseTest.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IPriorityPool.sol";

import "./ExecutorTestConstants.sol";

import "src/voting/onboardProposal/OnboardProposalEventError.sol";
import "src/voting/incidentReport/IncidentReportEventError.sol";
import "src/core/interfaces/ExecutorEventError.sol";

contract ExecutorTest is
    ExecutorEventError,
    ContractSetupBaseTest,
    ExecutorTestConstants,
    OnboardProposalEventError,
    IncidentReportEventError
{
    // Mock user addresses
    address internal alice = mkaddr("alice");
    address internal bob = mkaddr("bob");
    address internal charlie = mkaddr("charlie");

    // Mock priority pools
    IPriorityPool internal joePool;
    PriorityPool internal ptpPool;
    IPriorityPool internal gmxPool;

    // Mock native tokens for priority pools
    MockERC20 internal joe;
    MockERC20 internal ptp;
    MockERC20 internal gmx;

    address internal joeLPAddress;

    function setUp() public {
        setUpContracts();

        // Deploy one protocol token
        joe = new MockERC20("JoeToken", "JOE", 18);
        ptp = new MockERC20("PTPToken", "PTP", 18);
        gmx = new MockERC20("GMXToken", "GMX", 18);

        // Deploy one priority pool by owner
        joePool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "TraderJoe",
                address(joe),
                CAPACITY_1,
                PREMIUMRATIO_1
            )
        );

        joeLPAddress = joePool.currentLPAddress();

        // Mint usdc to provide liquidity
        usdc.mint(charlie, 1000 ether);

        vm.prank(charlie);
        usdc.approve(address(policyCenter), LIQUIDITY);

        // Provide Liquidity by one user
        vm.prank(charlie);
        policyCenter.provideLiquidity(LIQUIDITY);

        // Propose a new priority pool
        deg.mintDegis(charlie, PROPOSE_THRESHOLD);
        vm.warp(PROPOSE_TIME);
        vm.prank(charlie);
        onboardProposal.propose(
            "Platypus",
            address(ptp),
            CAPACITY_2,
            PREMIUMRATIO_2
        );

        // Proopose a new priority pool
        deg.mintDegis(charlie, PROPOSE_THRESHOLD);
        vm.warp(PROPOSE_TIME);
        vm.prank(charlie);
        onboardProposal.propose(
            "GMX",
            address(gmx),
            CAPACITY_3,
            PREMIUMRATIO_3
        );

        deg.mintDegis(charlie, REPORT_THRESHOLD);
        vm.warp(REPORT_TIME);
        vm.prank(charlie);
        incidentReport.report(1, PAYOUT);

        // Preparations
        veDEG.mint(alice, VOTE_AMOUNT * 2);
        veDEG.mint(bob, VOTE_AMOUNT * 2);
    }

    function _voteReport() private {
        vm.warp(INCIDENT_VOTE_TIME);
        incidentReport.startVoting(1);
        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(bob);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
    }

    function _voteProposal() private {
        vm.warp(PROPOSAL_VOTE_TIME);
        onboardProposal.startVoting(1);
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);
    }

    function testExecute() public {
        // # --------------------------------------------------------------------//
        // # Should not be able to execute Proposal prior to start voting # //
        // # --------------------------------------------------------------------//

        vm.warp(PROPOSAL_SETTLE_TIME);
        vm.expectRevert(Executor__ProposalNotSettled.selector);
        executor.executeProposal(1);

        // pool counter should not be increased and no new pool should be created
        assertEq(priorityPoolFactory.poolCounter(), 1);

        console.log(unicode"✅ Not execute a proposal prior to start voting");

        // # --------------------------------------------------------------------//
        // # Should not be able to execute Incident prior to start voting # //
        // # --------------------------------------------------------------------//

        vm.warp(INCIDENT_SETTLE_TIME);
        vm.expectRevert(Executor__ReportNotSettled.selector);
        executor.executeReport(1);

        // joe pool should not be liquidated after execution attempt
        // liquidation means deploying new generations of lp tokens
        assertEq(joePool.currentLPAddress(), joeLPAddress);

        console.log(unicode"✅ Not execute a report prior to start voting");

        // # --------------------------------------------------------------------//
        // # Should not be able to execute Proposal during voting # //
        // # --------------------------------------------------------------------//

        // vote for pool proposal and incident report
        _voteProposal();
        _voteReport();

        uint256 snapshot_1 = vm.snapshot();

        vm.expectRevert(Executor__ProposalNotSettled.selector);
        executor.executeProposal(1);

        assertEq(priorityPoolFactory.poolCounter(), 1);

        console.log(unicode"✅ Not execute a proposal during voting");

        // # --------------------------------------------------------------------//
        // # Should not be able to execute Incident during voting # //
        // # --------------------------------------------------------------------//

        vm.expectRevert(Executor__ReportNotSettled.selector);
        executor.executeReport(1);

        assertEq(joePool.currentLPAddress(), joeLPAddress);

        console.log(unicode"✅ Not execute a report during voting");

        // # --------------------------------------------------------------------//
        // # Should not be able to execute Proposal not settled # //
        // # --------------------------------------------------------------------//

        // revert to previous snapshot and take a new snapshot
        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        vm.expectRevert(Executor__ProposalNotSettled.selector);
        vm.warp(PROPOSAL_SETTLE_TIME);
        executor.executeProposal(1);

        console.log(unicode"✅ Not execute a proposal not settled");

        // # --------------------------------------------------------------------//
        // # Should not be able to execute Incident not settled # //
        // # --------------------------------------------------------------------//

        vm.expectRevert(Executor__ReportNotSettled.selector);
        vm.warp(INCIDENT_SETTLE_TIME);
        executor.executeReport(1);

        assertEq(joePool.currentLPAddress(), joeLPAddress);

        console.log(unicode"✅ Not execute a report not settled");

        // # --------------------------------------------------------------------//
        // # Should able to execute Proposal after settle # //
        // # --------------------------------------------------------------------//

        // revert to previous snapshot and take a new snapshot
        vm.revertTo(snapshot_2);

        vm.warp(PROPOSAL_SETTLE_TIME + 1);

        // Settle proposal
        onboardProposal.settle(1);

        // Get proposal record
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status, SETTLED_STATUS);
        assertEq(proposal.result, PASS_RESULT);

        // New ptp pool
        ptpPool = PriorityPool(executor.executeProposal(1));

        assertTrue(executor.proposalExecuted(1));

        assertEq(ptpPool.maxCapacity(), CAPACITY_2);
        assertEq(ptpPool.basePremiumRatio(), PREMIUMRATIO_2);
        // assertEq(ptpPool.priorityPoolFactory(), address(priorityPoolFactory));
        // assertEq(ptpPool.weightedFarmingPool(), address(farmingPool));
        // assertEq(ptpPool.protectionPool(), address(protectionPool));
        // assertEq(ptpPool.policyCenter(), address(policyCenter));
        // assertEq(ptpPool.payoutPool(), address(payoutPool));

        assertEq(ptpPool.coverIndex(), 10000);
        assertEq(ptpPool.priceIndex(ptpPool.currentLPAddress()), SCALE);

        assertEq(ptpPool.generation(), 1);

        console.log(unicode"✅ Execute a settled proposal");

        // # --------------------------------------------------------------------//
        // # Should able to execute Report after settle # //
        // # --------------------------------------------------------------------//

        vm.warp(INCIDENT_SETTLE_TIME + 1);

        // Settle incident report
        incidentReport.settle(1);

        executor.executeReport(1);

        assertTrue(executor.reportExecuted(1));

        IncidentReport.Report memory report = incidentReport.getReport(1);

        // Check the report record is intanct
        assertEq(report.poolId, 1);
        assertEq(report.reporter, charlie);
        assertEq(report.reportTimestamp, REPORT_TIME);
        assertEq(report.status, SETTLED_STATUS);
        assertEq(report.payout, PAYOUT);
        assertEq(report.result, PASS_RESULT);

        // Pool should be liquidated
        assertTrue(joePool.currentLPAddress() != joeLPAddress);

        console.log(unicode"✅ Execute a settled report");
    }
}
