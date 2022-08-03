// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ReinsurancePool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/OnboardProposal.sol";
import "src/voting/IncidentReport.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";
import "src/mock/MockExchange.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/ReinsurancePoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

import "src/voting/interfaces/IncidentReportParameters.sol";

abstract contract Events {
    event ReportCreated(
        uint256 reportId,
        uint256 indexed poolId,
        uint256 reportTimestamp,
        address indexed reporter
    );

    event VotingStart(uint256 reportId, uint256 startTimestamp);

    event ReportClosed(uint256 reportId, uint256 closeTimestamp);

    event ReportVoted(
        uint256 reportId,
        address indexed user,
        uint256 voteFor,
        uint256 amount
    );

    event ReportSettled(uint256 reportId, uint256 result);

    event ReportExtended(uint256 reportId, uint256 round);

    event DebtPaid(
        address payer,
        address user,
        uint256 debt,
        uint256 unlockAmount
    );
}

contract IncidentReportTest is Test, IncidentReportParameters, Events {
    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;
    Exchange public exchange;

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;

    uint256 constant VOTE_FOR = 1;
    uint256 constant VOTE_AGAINST = 2;

    uint256 constant POOL_ID = 1;

    uint256 constant REPORT_START_TIME = 1000;

    function setUp() public {
        // deploys tokens
        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);

        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        deg.approve(address(policyCenter), 10000 ether);
        deg.transfer(address(this), 100 ether);
        vedeg = new MockVeDEG(1000 ether, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100 ether);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);

        deg.addMinter(address(this));

        vedeg.mint(alice, 100000 ether);
        vedeg.mint(bob, 100000 ether);
        vedeg.mint(carol, 10000 ether);

        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(
            address(reinsurancePool),
            address(deg)
        );
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        onboardProposal = new OnboardProposal();
        exchange = new Exchange();
        incidentReport = new IncidentReport();

        deg.addMinter(address(incidentReport));

        // approve incident report interaction
        deg.approve(address(incidentReport), 10000 ether);
        vedeg.approve(address(incidentReport), 10000 ether);
        ptp.approve(address(incidentReport), 10000 ether);

        // sets addresses needed to execute functions
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setOnboardProposal(address(onboardProposal));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setExecutor(address(executor));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setOnboardProposal(address(onboardProposal));
        insurancePoolFactory.setIncidentReport(address(incidentReport));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setOnboardProposal(address(onboardProposal));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        incidentReport.setDeg(address(deg));
        incidentReport.setVeDeg(address(vedeg));
        incidentReport.setShield(address(shield));
        incidentReport.setExecutor(address(executor));
        incidentReport.setPolicyCenter(address(policyCenter));
        incidentReport.setReinsurancePool(address(reinsurancePool));
        incidentReport.setInsurancePoolFactory(address(insurancePoolFactory));
        executor.setDeg(address(deg));
        executor.setVeDeg(address(vedeg));
        executor.setShield(address(shield));
        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        //deploy ptp pool
        pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            10000,
            100
        );
        // set addreses for ptp pool
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setIncidentReport(address(incidentReport));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setReinsurancePool(address(reinsurancePool));
        InsurancePool(pool1).setInsurancePoolFactory(
            address(insurancePoolFactory)
        );
        
        // allow incident report to mint and burn tokens on behalf of users
        // in the protocol's interest.
        deg.addMinter(address(incidentReport));

        vm.warp(REPORT_START_TIME);
        incidentReport.report(POOL_ID);
    }

    function _report(uint256 _id) public {
        incidentReport.report(_id);
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
