// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/pools/protectionPool/ProtectionPool.sol";
import "src/pools/PayoutPool.sol";
import "src/pools/PremiumRewardPool.sol";
import "src/core/PolicyCenter.sol";
import "src/pools/PayoutPool.sol";

import "src/voting/onboardProposal/OnboardProposal.sol";
import "src/voting/ProposalCenter.sol";
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

contract ProposalCenterTest is Test {
    PriorityPoolFactory public priorityPoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    PayoutPool public payoutPool;
    PremiumRewardPool public premiumRewardPool;
    OnboardProposal public onboardProposal;
    ProposalCenter public proposalCenter;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    Executor public executor;
    Exchange public exchange;
    ERC20 public ptp;
    ERC20 public yeti;

    struct Report {
        uint256 poolId; // Project pool id
        uint256 reportTimestamp; // Time of starting report
        address reporter; // Reporter address
        uint256 voteTimestamp; // Voting start timestamp
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 round; // 0: Initial round 3 days, 1: Extended round 1 day, 2: Double extended 1 day
        uint256 status;
        uint256 result; // 1: Pass, 2: Reject, 3: Tied
        uint256 votingReward; // Voting reward per veDEG if the report passed
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

        vedeg = new MockVeDEG(10000 ether, "VeDEG", 18, "VEDEG");
        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");

        deg.transfer(address(this), 100 ether);

        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        vm.label(address(ptp), "ptp");

        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);
        vm.label(address(yeti), "yeti");

        //
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
        priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));
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
        incidentReport = new IncidentReport(
            address(deg),
            address(vedeg),
            address(shield)
        );

        // deploy proposal center
        proposalCenter = new ProposalCenter(
            address(onboardProposal),
            address(incidentReport)
        );

        exchange = new Exchange();

        shield.approve(address(policyCenter), 20000 ether);
        deg.approve(address(policyCenter), 10000 ether);

        priorityPoolFactory.setExecutor(address(executor));
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setProtectionPool(address(protectionPool));
        protectionPool.setPolicyCenter(address(policyCenter));
        protectionPool.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExecutor(address(executor));
        policyCenter.setExchange(address(exchange));
        policyCenter.setProtectionPool(address(protectionPool));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        onboardProposal.setExecutor(address(executor));
        onboardProposal.setProposalCenter(address(proposalCenter));
        onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));

        incidentReport.setProposalCenter(address(proposalCenter));
        incidentReport.setPriorityPoolFactory(address(priorityPoolFactory));
        
        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setIncidentReport(address(incidentReport));
        executor.setProtectionPool(address(protectionPool));
        executor.setPriorityPoolFactory(address(priorityPoolFactory));

        // pools require initial liquidity input to Protection pool
        // policyCenter.provideLiquidity(10000 ether);

        // create insurance pool
        pool1 = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            10000 ether,
            100
        );

        // set insurance pool addresses
        PriorityPool(pool1).setPolicyCenter(address(policyCenter));

        deg.transfer(address(this), 1000 ether);

        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 3000 ether);
        vedeg.transfer(carol, 3000 ether);
        vedeg.transfer(address(this), 1000 ether);

        // approve deg to propose a new pool on onboard proposal
        deg.approve(address(onboardProposal), 10000 ether);

        vm.warp(0);
    }

    function testPoolProposalCenter() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.protocolToken, address(yeti));
    }

    function testExistingPoolProposalCenter() public {
        vm.expectRevert("Protocol already protected");
        proposalCenter.proposePool("Platypus", address(ptp), 10000 ether, 100);
    }

    function testVoteProposalCenter() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(PROPOSAL_ID);
        // vote with 3 participants
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 3000 ether);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);

        uint256 aliceChoice = onboardProposal.getUserProposalVote(
            alice,
            PROPOSAL_ID
        );
        uint256 bobChoice = onboardProposal.getUserProposalVote(
            bob,
            PROPOSAL_ID
        );
        uint256 carolChoice = onboardProposal.getUserProposalVote(
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
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        // user should not be able to vote with morethan
        // how much they have committed to the proposal
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(PROPOSAL_ID);
        vm.prank(alice);
        // votes with maximum amount of veDeg to proposal
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);

        vm.prank(alice);
        vm.expectRevert("Not enough veDEG");
        proposalCenter.votePoolProposal(1, VOTE_FOR, 1000 ether);
    }

    function testEvaluatePoolProposalTrue() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        // pool proposal should be truthy if majority of votes are true
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(PROPOSAL_ID);
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 3000 ether);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);

        vm.warp(6 days + 1);
        proposalCenter.settleProposal(1);

        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.result == VOTE_FOR, true);
        assertEq(proposal.status == SETTLED_STATUS, true);
    }

    function testEvaluatePoolProposalFalse() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        // pool proposal should be false if majority of votes are false
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(1);

        vm.prank(alice);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 2500 ether);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 2500 ether);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 2000 ether);

        // move time forward 6 days
        vm.warp(6 days + 2);
        proposalCenter.settleProposal(1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.result == VOTE_AGAINST, true);
        assertEq(proposal.status == SETTLED_STATUS, true);
    }

    function testVoteProposalNotEnoughQuorum() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(1);
        // vote with 3 participants
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 500 ether);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 500 ether);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 500 ether);

        vm.warp(6 days + 2);
        vm.expectRevert("Not reached quorum");
        onboardProposal.settle(1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status == VOTING_STATUS, true);
    }

    function testProposePoolAlreadyDeployed() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        vm.warp(3 days + 1);
        // pool proposal should not be proposed twice
        vm.prank(alice);
        vm.expectRevert("Protocol already protected");
        onboardProposal.propose("Platypus", address(ptp), 100, 1);
    }

    function testProposePoolAlreadyProposed() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        // pool proposal should not be proposed twice
        deg.transfer(alice, 1000 ether);
        vm.prank(alice);
        deg.approve(address(onboardProposal), 10000 ether);
        vm.prank(alice);
        vedeg.approve(address(onboardProposal), 10000 ether);
        vm.prank(alice);
        vm.expectRevert("Protocol already proposed");
        onboardProposal.propose("Yeti", address(yeti), 100, 1);
    }

    function testProposePoolAfterFailedProposal() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(1);
        // after a failed proposal, a new proposal should be possible
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 3000 ether);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 3000 ether);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, VOTE_AGAINST, 3000 ether);

        vm.warp(6 days + 2);
        // settle proposal after voting period
        onboardProposal.settle(1);
        OnboardProposal.Proposal memory proposal1 = onboardProposal.getProposal(
            1
        );
        assertEq(proposal1.status == SETTLED_STATUS, true);

        // propose new pool after settling proposal
        proposalCenter.proposePool("Yeti", address(yeti), 10000, 1);
        // pool proposal is not pending and was false.
        OnboardProposal.Proposal memory proposal2 = onboardProposal.getProposal(
            2
        );
        assertEq(proposal2.status == PENDING_STATUS, true);
    }

    function testProposePoolAfterSuccessfulProposal() public {
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
        vm.warp(3 days + 1);
        proposalCenter.startProposalVoting(1);

        vm.prank(alice);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, VOTE_FOR, 3000 ether);

        vm.warp(6 days + 2);
        // settle proposal after voting period
        proposalCenter.settleProposal(1);
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status == SETTLED_STATUS, true);

        executor.executeProposal(1);

        vm.expectRevert("Protocol already protected");
        proposalCenter.proposePool("Yeti", address(yeti), 10000 ether, 100);
    }
}
