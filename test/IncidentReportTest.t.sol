// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
import "./utils/BaseTest.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import "src/mock/MockERC20.sol";
import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/pools/protectionPool/ProtectionPool.sol";
import "src/pools/PayoutPool.sol";
import "src/reward/WeightedFarmingPool.sol";
import "src/pools/PremiumRewardPool.sol";
import "src/core/PolicyCenter.sol";

import "src/voting/onboardProposal/OnboardProposal.sol";
import "src/voting/incidentReport/IncidentReport.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";
import "src/mock/MockExchange.sol";

import "src/interfaces/IPriorityPool.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IProtectionPool.sol";
import "src/interfaces/IPriorityPool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

import "src/voting/incidentReport/IncidentReportParameters.sol";
import "src/voting/incidentReport/IncidentReportEventError.sol";

contract IncidentReportTest is
    BaseTest,
    IncidentReportParameters,
    IncidentReportEventError
{
    // Contracts in test
    PriorityPoolFactory public priorityPoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    WeightedFarmingPool public weightedFarmingPool;
    PayoutPool public payoutPool;
    PremiumRewardPool public premiumRewardPool;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    PriorityPool public insurancePool;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;
    Exchange public exchange;

    // Users in test
    address public ALICE = mkaddr("Alice");
    address public BOB = mkaddr("Bob");
    address public CHARLIE = mkaddr("Charlie");

    // pool1 address
    address public pool1;

    uint256 constant VOTE_FOR = 1;
    uint256 constant VOTE_AGAINST = 2;

    uint256 constant POOL_ID = 1;

    uint256 constant REPORT_START_TIME = 1000;

    function setUp() public {
        // Deploy tokens
        shield = new MockSHIELD(0, "Shield", 6, "SHIELD");
        deg = new MockDEG(0, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(0, "veDegis", 18, "veDeg");
        ptp = new MockERC20("Platypus", "PTP", 18);
        yeti = new MockERC20("Yeti", "YETI", 18);

        deg.mintDegis(address(this), 100 ether);
        vedeg.mint(address(this), 100 ether);

        vedeg.mint(ALICE, 100000 ether);
        vedeg.mint(BOB, 100000 ether);
        vedeg.mint(CHARLIE, 10000 ether);

        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );
        priorityPoolFactory = new PriorityPoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool),
            address(payoutPool)
        );
        premiumRewardPool = new PremiumRewardPool(
            address(shield),
            address(priorityPoolFactory),
            address(protectionPool)
        );
        policyCenter = new PolicyCenter(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );
        executor = new Executor();
        onboardProposal = new OnboardProposal(
            address(deg),
            address(vedeg),
            address(shield)
        );
        exchange = new Exchange();

        shield.approve(address(policyCenter), 20000);
        deg.approve(address(policyCenter), 10000 ether);

        incidentReport = new IncidentReport(
            address(deg),
            address(vedeg),
            address(shield)
        );

        weightedFarmingPool = new WeightedFarmingPool(
            address(premiumRewardPool)
        );
        weightedFarmingPool.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setWeightedFarmingPool(
            address(weightedFarmingPool)
        );
        policyCenter.setWeightedFarmingPool(address(weightedFarmingPool));

        // approve incident report interaction
        deg.approve(address(incidentReport), 10000 ether);
        vedeg.approve(address(incidentReport), 10000 ether);
        ptp.approve(address(incidentReport), 10000 ether);

        // sets addresses needed to execute functions

        policyCenter.setExecutor(address(executor));

        incidentReport.setPriorityPoolFactory(address(priorityPoolFactory));

        policyCenter.setProtectionPool(address(protectionPool));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExchange(address(exchange));

        priorityPoolFactory.setExecutor(address(executor));
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setProtectionPool(address(protectionPool));
        priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));

        protectionPool.setPolicyCenter(address(policyCenter));
        protectionPool.setIncidentReport(address(incidentReport));
        protectionPool.setPolicyCenter(address(policyCenter));

        executor.setOnboardProposal(address(onboardProposal));

        executor.setPriorityPoolFactory(address(priorityPoolFactory));
        executor.setIncidentReport(address(incidentReport));

        shield.transfer(address(this), 10000 ether);
        shield.approve(address(policyCenter), 10000 ether);
        // pools require initial liquidity input to Protection pool
        policyCenter.provideLiquidity(10000 ether);

        //deploy ptp pool
        pool1 = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            10000,
            100
        );
        // set addreses for ptp pool

        PriorityPool(pool1).setIncidentReport(address(incidentReport));
        PriorityPool(pool1).setPolicyCenter(address(policyCenter));

        vm.warp(REPORT_START_TIME);
        incidentReport.report(POOL_ID, 100 ether);
    }

    function _report(uint256 _id) public {
        incidentReport.report(_id, 100 ether);
    }

    function testExecuteReportBeforeBeingQueued() public {
        // a report should only be executable once its queued in the executor
        vm.expectRevert("Report is not ready to be executed");
        executor.executeReport(1);
    }

    function testStartReport() public {
        IncidentReport.Report memory currentReport = incidentReport.getReport(
            1
        );

        assertEq(currentReport.poolId, POOL_ID);
        assertEq(currentReport.reportTimestamp, 1000);
        assertEq(currentReport.reporter, address(this));
    }

    function testStartVoting() public {
        // Can not start report before passing the pending period
        vm.expectRevert("Not passed pending period");
        incidentReport.startVoting(POOL_ID);

        // Time setup
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);

        // Event check
        vm.expectEmit(true, true, false, true);
        emit VotingStart(1, REPORT_START_TIME + PENDING_PERIOD + 1);

        incidentReport.startVoting(POOL_ID);

        IncidentReport.Report memory report = incidentReport.getReport(1);

        assertEq(report.status, VOTING_STATUS);
        assertEq(report.voteTimestamp, REPORT_START_TIME + PENDING_PERIOD + 1);
    }

    function testCloseReport() public {
        // Can not close a report after pending period
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        vm.expectRevert("Already passed pending period");
        incidentReport.closeReport(1);

        // Can close a report before pending period
        vm.warp(REPORT_START_TIME + PENDING_PERIOD);
        incidentReport.closeReport(1);

        IncidentReport.Report memory report = incidentReport.getReport(1);

        assertEq(report.status, CLOSE_STATUS);
    }

    function testVoteReport() public {
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        // Alice vote for
        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 2500 ether);

        // Bob vote against
        vm.prank(bob);
        incidentReport.vote(1, VOTE_AGAINST, 2000 ether);

        // Carol vote for
        vm.prank(carol);
        incidentReport.vote(1, VOTE_FOR, 1500 ether);

        // Get their votes record
        IncidentReport.UserVote memory aliceVote = incidentReport.getUserVote(
            alice,
            1
        );
        IncidentReport.UserVote memory bobVote = incidentReport.getUserVote(
            bob,
            1
        );
        IncidentReport.UserVote memory carolVote = incidentReport.getUserVote(
            carol,
            1
        );

        // Check if votes are recorded
        assertEq(aliceVote.choice, VOTE_FOR);
        assertEq(aliceVote.amount, 2500 ether);
        assertEq(aliceVote.claimed, false);

        assertEq(bobVote.choice, VOTE_AGAINST);
        assertEq(carolVote.choice, VOTE_FOR);
    }

    function testVoteMoreThanOnceOnReport() public {
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        vm.startPrank(alice);
        incidentReport.vote(1, VOTE_FOR, 2500 ether);

        // Can vote multiple times for the same choice
        incidentReport.vote(1, VOTE_FOR, 2500 ether);

        IncidentReport.UserVote memory aliceVote = incidentReport.getUserVote(
            alice,
            1
        );
        assertEq(aliceVote.choice, VOTE_FOR);
        assertEq(aliceVote.amount, 5000 ether);

        // Can not switch to another choice
        vm.expectRevert("Can not choose both sides");
        incidentReport.vote(1, VOTE_AGAINST, 2500 ether);

        vm.stopPrank();
    }

    function testSettleReport() public {
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 10000 ether);

        // Can not settle before end voting
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD);
        vm.expectRevert("Not reached settlement");
        incidentReport.settle(1);

        // Can not settle without reaching quorum
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);
        vm.expectRevert("Not reached quorum");
        incidentReport.settle(1);

        // Successfully settle the report
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);
        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 90000 ether);
        incidentReport.settle(1);

        IncidentReport.Report memory report = incidentReport.getReport(1);

        assertEq(report.status, SETTLED_STATUS);
        assertEq(report.result, PASS_RESULT);
        assertEq(report.numFor, 100000 ether);
        assertEq(report.numAgainst, 0);
    }

    function testExtendRound() public {
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 100000 ether);

        // Vote against in the last SAMPLE_PERIOD
        // Result still for now
        vm.warp(
            REPORT_START_TIME +
                PENDING_PERIOD +
                VOTING_PERIOD -
                SAMPLE_PERIOD +
                1
        );
        vm.prank(bob);
        incidentReport.vote(1, VOTE_AGAINST, 50000 ether);

        IncidentReport.TempResult memory temp_1 = incidentReport.getTempResult(
            1
        );
        assertEq(temp_1.result, INIT_RESULT);
        assertEq(temp_1.sampleTimestamp, 0);
        assertEq(temp_1.hasChanged, false);

        // Vote against twice in the last SAMPLE_PERIOD
        // Result change to tied now
        vm.warp(
            REPORT_START_TIME +
                PENDING_PERIOD +
                VOTING_PERIOD -
                SAMPLE_PERIOD +
                2
        );
        vm.prank(bob);
        incidentReport.vote(1, VOTE_AGAINST, 20000 ether);

        IncidentReport.TempResult memory temp_2 = incidentReport.getTempResult(
            1
        );
        assertEq(temp_2.result, PASS_RESULT);
        assertEq(temp_2.hasChanged, false);

        // Vote against twice in the last SAMPLE_PERIOD
        // Result change to tied now
        vm.warp(
            REPORT_START_TIME +
                PENDING_PERIOD +
                VOTING_PERIOD -
                SAMPLE_PERIOD +
                3
        );
        vm.prank(bob);
        incidentReport.vote(1, VOTE_AGAINST, 30000 ether);

        IncidentReport.TempResult memory temp_3 = incidentReport.getTempResult(
            1
        );
        assertEq(temp_3.result, TIED_RESULT);
        assertEq(temp_3.hasChanged, true);

        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);
        vm.expectEmit(false, false, false, true);
        emit ReportExtended(1, 1);
        incidentReport.settle(1);

        IncidentReport.Report memory report = incidentReport.getReport(1);
        assertEq(report.round, 1);
        assertEq(report.result, INIT_RESULT);
    }

    function testClaimRewardAndPayDebtAfterPassed() public {
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 100000 ether);

        vm.prank(bob);
        incidentReport.vote(1, VOTE_AGAINST, 50000 ether);

        uint256 balanceBefore = deg.balanceOf(address(this));

        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);
        incidentReport.settle(1);

        uint256 balanceAfter = deg.balanceOf(address(this));

        // Get back 1000 deg and extra 1000 deg reward
        assertEq(balanceAfter - balanceBefore, 2000 ether);

        vm.prank(alice);
        incidentReport.claimReward(1);

        assertEq(vedeg.locked(alice), 0);
        assertEq(deg.balanceOf(alice), 500 ether);

        deg.mintDegis(bob, 500 ether);
        vm.prank(bob);
        incidentReport.payDebt(1, bob);

        // Pay 400 deg for debt, left 100 deg
        assertEq(deg.balanceOf(bob), 100 ether);
    }

    function testClaimRewardAndPayDebtAfterRejected() public {
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 50000 ether);

        vm.prank(bob);
        incidentReport.vote(1, VOTE_AGAINST, 100000 ether);

        uint256 balanceBefore = deg.balanceOf(address(this));

        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);
        incidentReport.settle(1);

        uint256 balanceAfter = deg.balanceOf(address(this));

        // Not passed, can not get back
        assertEq(balanceAfter - balanceBefore, 0);

        vm.prank(bob);
        incidentReport.claimReward(1);

        assertEq(vedeg.locked(bob), 0);
        assertEq(deg.balanceOf(bob), 1500 ether);

        deg.mintDegis(alice, 500 ether);
        vm.prank(alice);
        incidentReport.payDebt(1, alice);

        // Pay 400 deg for debt, left 100 deg
        assertEq(deg.balanceOf(alice), 100 ether);
    }
}
