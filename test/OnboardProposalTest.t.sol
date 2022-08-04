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

contract OnboardProposalTest is Test {
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

    function setUp() public {
        // deploys tokens
        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);
        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        deg.approve(address(policyCenter), 10000 ether);
        deg.transfer(address(this), 100 ether);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);

        deg.approve(address(this), 10000 ether);
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100 ether);
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(
            address(reinsurancePool),
            address(deg)
        );
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        onboardProposal = new OnboardProposal();
        exchange = new Exchange();

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
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setOnboardProposal(address(onboardProposal));
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        onboardProposal.setDeg(address(deg));
        onboardProposal.setVeDeg(address(vedeg));
        onboardProposal.setShield(address(shield));
        onboardProposal.setExecutor(address(executor));
        onboardProposal.setPolicyCenter(address(policyCenter));
        onboardProposal.setReinsurancePool(address(reinsurancePool));
        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));
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
            10000 ether,
            100
        );
        // set addreses for ptp pool
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setReinsurancePool(address(reinsurancePool));
        InsurancePool(pool1).setInsurancePoolFactory(
            address(insurancePoolFactory)
        );
    }

    function testProposePool() public {
        // add onboardProposal to mint and burn tokens
        deg.addMinter(address(onboardProposal));

        // propose a yeti pool
        onboardProposal.propose("Yeti", address(yeti), 10000, 1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );

        // proposal is recorded
        assertEq(proposal.protocolToken == address(yeti), true);
    }
}

contract OnboardProposalVotingTest is Test {
    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    Executor public executor;
    Exchange public exchange;
    ERC20 public ptp;
    ERC20 public yeti;

    struct UserVote {
        uint256 choice;
        uint256 amount;
        bool claimed;
    }

    struct Proposal {
        string name;
        address protocolAddress;
        address proposer;
        uint256 proposeTimestamp;
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 maxCapacity;
        uint256 priceRatio;
        uint256 poolId;
        uint256 status;
        uint256 result;
    }

    uint256 public constant VOTE_FOR = 1;
    uint256 public constant VOTE_AGAINST = 2;

    uint256 public constant PROPOSAL_ID = 1;

    uint256 public constant INIT_STATUS = 0;
    uint256 public constant PENDING_STATUS = 1;
    uint256 public constant VOTING_STATUS = 2;
    uint256 public constant SETTLED_STATUS = 3;
    uint256 public constant CLOSE_STATUS = 404;

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;

    function setUp() public {
        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);
        vedeg = new MockVeDEG(10000 ether, "VeDEG", 18, "VEDEG");
        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        deg.approve(address(policyCenter), 10000 ether);
        deg.transfer(address(this), 100 ether);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        vm.label(address(ptp), "ptp");
        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);
        vm.label(address(yeti), "yeti");

        //
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(
            address(reinsurancePool),
            address(deg)
        );
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        onboardProposal = new OnboardProposal();
        incidentReport = new IncidentReport();
        exchange = new Exchange();

        
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setExecutor(address(executor));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setOnboardProposal(address(onboardProposal));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setExecutor(address(executor));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setOnboardProposal(address(onboardProposal));
        reinsurancePool.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setExchange(address(exchange));
        policyCenter.setOnboardProposal(address(onboardProposal));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        onboardProposal.setDeg(address(deg));
        onboardProposal.setVeDeg(address(vedeg));
        onboardProposal.setShield(address(shield));
        onboardProposal.setExecutor(address(executor));
        onboardProposal.setPolicyCenter(address(policyCenter));
        onboardProposal.setReinsurancePool(address(reinsurancePool));
        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));
        executor.setDeg(address(deg));
        executor.setVeDeg(address(vedeg));
        executor.setShield(address(shield));
        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setIncidentReport(address(incidentReport));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        // create insurance pool
        pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            10000 ether,
            100
        );
        console.log(pool1);
        // set insurance pool addresses
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setInsurancePoolFactory(
            address(insurancePoolFactory)
        );

        deg.transfer(address(this), 1000 ether);
        deg.approve(address(onboardProposal), 10000 ether);
        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 3000 ether);
        vedeg.transfer(carol, 3000 ether);
        vedeg.transfer(address(this), 1000 ether);

        // approve deg to propose a new pool on onboard proposal
        deg.approve(address(onboardProposal), 10000 ether);
        // allow onboardProposal to mint and burn degis tokens
        // in the protocol interest and on users' behalf
        deg.addMinter(address(onboardProposal));
        vm.warp(0);
        onboardProposal.propose("Yeti", address(yeti), 10000, 1);

        shield.transfer(alice, 3000 ether);
    }

    function testExecuteReportBeforeBeingQueued() public {
        // a report should only be executable once its queued in the executor
        vm.expectRevert("Report is not ready to be executed");
        executor.executeReport(1);
    }

    function testVoteProposal() public {
        vm.warp(3 days + 1);
        onboardProposal.startVoting(PROPOSAL_ID);
        // vote with 3 participants
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST, 3000 ether);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);

        (uint256 aliceChoice, , ) = onboardProposal.userProposalVotes(
            alice,
            PROPOSAL_ID
        );
        (uint256 bobChoice, , ) = onboardProposal.userProposalVotes(
            bob,
            PROPOSAL_ID
        );
        (uint256 carolChoice, , ) = onboardProposal.userProposalVotes(
            carol,
            PROPOSAL_ID
        );

        // check if votes are recorded
        // does not check if vote for or against proposal
        assertEq(aliceChoice == VOTE_FOR, true);
        assertEq(bobChoice == VOTE_AGAINST, true);
        assertEq(carolChoice == VOTE_FOR, true);
    }

    function testVoteMoreThanOnceOnPoolProposal() public {
        // user should not be able to vote with morethan
        // how much they have committed to the proposal
        vm.warp(3 days + 1);
        onboardProposal.startVoting(PROPOSAL_ID);
        vm.prank(alice);
        // votes with maximum amount of veDeg to proposal
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);

        vm.prank(alice);
        vm.expectRevert("Not enough veDEG");
        onboardProposal.vote(1, VOTE_FOR, 1000 ether);
    }

    function testEvaluatePoolProposalTrue() public {
        // pool proposal should be truthy if majority of votes are true
        vm.warp(3 days + 1);
        onboardProposal.startVoting(PROPOSAL_ID);
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST, 3000 ether);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);

        vm.warp(6 days + 1);
        onboardProposal.settle(1);

        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.result == VOTE_FOR, true);
        assertEq(proposal.status == SETTLED_STATUS, true);
    }

    function testEvaluatePoolProposalFalse() public {
        // pool proposal should be false if majority of votes are false
        vm.warp(3 days + 1);
        onboardProposal.startVoting(1);

        vm.prank(alice);
        onboardProposal.vote(1, VOTE_AGAINST, 2500 ether);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST, 2500 ether);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR, 2000 ether);

        // move time forward 6 days
        vm.warp(6 days + 2);
        onboardProposal.settle(1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.result == VOTE_AGAINST, true);
        assertEq(proposal.status == SETTLED_STATUS, true);
    }

    function testVoteProposalNotEnoughQuorum() public {
        vm.warp(3 days + 1);
        onboardProposal.startVoting(1);
        // vote with 3 participants
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR, 500 ether);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_FOR, 500 ether);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR, 500 ether);

        vm.warp(6 days + 2);
        vm.expectRevert("Not reached quorum");
        onboardProposal.settle(1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status == VOTING_STATUS, true);
    }

    function testProposePoolAlreadyDeployed() public {
        vm.warp(3 days + 1);
        // pool proposal should not be proposed twice
        vm.prank(alice);
        vm.expectRevert("Protocol already protected");
        onboardProposal.propose("Platypus", address(ptp), 100 ether, 1);
    }

    function testProposePoolAlreadyProposed() public {
        // pool proposal should not be proposed twice
        deg.transfer(alice, 1000 ether);
        vm.prank(alice);
        deg.approve(address(onboardProposal), 10000 ether);
        vm.prank(alice);
        vedeg.approve(address(onboardProposal), 10000 ether);
        vm.prank(alice);
        vm.expectRevert("Protocol already proposed");
        onboardProposal.propose("Yeti", address(yeti), 100 ether, 1);
    }

    function testProposePoolAfterFailedProposal() public {
        vm.warp(3 days + 1);
        onboardProposal.startVoting(1);
        // after a failed proposal, a new proposal should be possible
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_AGAINST, 3000 ether);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST, 3000 ether);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_AGAINST, 3000 ether);

        vm.warp(6 days + 2);
        // settle proposal after voting period
        onboardProposal.settle(1);
        OnboardProposal.Proposal memory proposal1 = onboardProposal.getProposal(
            1
        );
        assertEq(proposal1.status == SETTLED_STATUS, true);

        // propose new pool after settling proposal
        onboardProposal.propose("Yeti", address(yeti), 10000, 1);
        // pool proposal is not pending and was false.
        OnboardProposal.Proposal memory proposal2 = onboardProposal.getProposal(
            2
        );
        assertEq(proposal2.status == PENDING_STATUS, true);
    }

    function testProposePoolAfterSuccessfulProposal() public {
        vm.warp(3 days + 1);
        onboardProposal.startVoting(1);

        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR, 3000 ether);

        vm.warp(6 days + 2);
        // settle proposal after voting period
        onboardProposal.settle(1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status == SETTLED_STATUS, true);

        executor.executeProposal(1);

        vm.expectRevert("Protocol already protected");
        onboardProposal.propose("Yeti", address(yeti), 10000, 1);
    }
}
