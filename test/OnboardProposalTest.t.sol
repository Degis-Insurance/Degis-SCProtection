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

import "src/interfaces/IComittee.sol";
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
        deg.transfer(address(this), 100e18);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000 ether);

        deg.approve(address(this), 10000 ether);
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100e18);
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
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
        pool1 = insurancePoolFactory.deployPool("PTP", address(ptp), uint256(10000), uint256(1));
         // set addreses for ptp pool
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setReinsurancePool(address(reinsurancePool));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
    }

    
    function testProposePool() public {
        // propose a yeti pool
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);
        (string memory protocolName,
        address protocolAddress,,,,,,,,) = onboardProposal.getProposal(1);
        console.log(protocolName);
        // proposal is recorded
        assertEq(protocolAddress == address(yeti), true);
    }

    function testSetPoolProposed() public {
        // set pooll as proposed. only owner
        onboardProposal.setPoolProposed(address(yeti), true);
        assertEq(onboardProposal.poolProposed(address(yeti)) == true, true);
    }

    function testSetPoolProposedNotByOwner() public {
        // set pooll as proposed. only owner
        vm.prank(alice);
        vm.expectRevert("Only owner or executor can call this function");
        onboardProposal.setPoolProposed(address(yeti), true);
    }

  
    function setProposalStatus() public {
        // change proposal status by owner
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);
        onboardProposal.setProposalApproval(1, true);
        (,,,,,,,,,bool approved) = onboardProposal.getProposal(1);
        assertEq( approved == true, true);
    }

    function setProposalStatusNotByOwner() public {
        // non owner should not be able to set proposal status
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);
        vm.prank(alice);
        vm.expectRevert("Only owner or executor can call this function");
        onboardProposal.setProposalApproval(1, true);
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
    InsurancePool public insurancePool;
    Executor public executor;
    Exchange public exchange;
    ERC20 public ptp;
    ERC20 public yeti;

    uint256 constant public VOTE_FOR = 1;
    uint256 constant public VOTE_AGAINST = 2;

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
        deg.transfer(address(this), 100e18);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000 ether);
        // 
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
        onboardProposal = new OnboardProposal();
        exchange = new Exchange();

        vm.label(address(onboardProposal), "Proposal Center");
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
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        // create insurance pool
        pool1 = insurancePoolFactory.deployPool("PTP", address(ptp), 10000 ether, 1);
        console.log(pool1);
        // set insurance pool addresses
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));

        deg.transfer(address(this), 1000e18);
        deg.approve(address(onboardProposal), 10000 ether);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 1500e18);
        vedeg.transfer(carol, 1600e18);
        vedeg.transfer(address(this), 1000e18);
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);

        shield.transfer(alice, 3000e18);
    }

    function testExecuteReportBeforeBeingQueued() public {
        // a report should only be executable once its queued in the executor
        vm.expectRevert("report not pending or not found");
       executor.executeReport(1);
    }

    function testVoteProposal() public {
        // vote with 3 participants 
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR);
        (,,address[] memory voted,,,,,,,) = onboardProposal.getProposal(1);
        bool aliceVoted;
        bool bobVoted;
        bool carolVoted;
        for (uint i = 0; i < voted.length; i++){
            console.log(voted[i]);
            if (voted[i] == alice){
                aliceVoted = true;
            } else if (voted[i] == bob){
                bobVoted = true;
            } else if ( voted[i] == carol) {
               carolVoted = true;
            }
        }
        // check if votes are recorded
        // does not check if vote for or against proposal
        assertEq(aliceVoted == true, true);
        assertEq(bobVoted == true, true);
        assertEq(carolVoted == true, true);
    }

    

    function testVoteMoreThanOnceOnPoolProposal() public {
        // user should not be able to vote twice
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        onboardProposal.vote(1, VOTE_FOR);
    }

   

    function testEvaluatePoolProposalTrue() public {
        // pool proposal should be truthy if majority of votes are true
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR);
        vm.warp(604801);
        vm.prank(address(0x11133159));
        onboardProposal.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool approved) = onboardProposal.getProposal(1);
        assertEq(approved == true, true);
    }

    function testEvaluatePoolProposalFalse() public {
        // pool proposal should be false if majority of votes are false
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR);
        vm.warp(604801);
        vm.prank(address(0x11133159));
        onboardProposal.evaluatePoolProposalVotes(1);    
        (,,,,,,,,,bool approved) = onboardProposal.getProposal(1);
        assertEq(approved == false, true); 
    }

   


    function testProposePooolAlreadyProposed() public {
        // pool proposal should not be proposed twice
        vm.prank(alice);
        vm.expectRevert("Protocol already proposed");
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);
    }

   
    function testProposePoolAfterFailedProposal() public {
        // after a failed proposal, a new proposal should be possible
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_AGAINST);
        vm.warp(260000);
        vm.prank(address(0x11133159));
        // evaluate proposal round 0
        onboardProposal.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        vm.prank(address(0x11133159));
        // evaluate proposal round 1: approval did not change, proposal moves on.
        onboardProposal.evaluatePoolProposalVotes(1);
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);
        // pool proposal is not pending and was false.
        (,,,,,,,,bool pending1,bool approved1) = onboardProposal.getProposal(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        // new pool proposal is pending and is still not approved
        (,,,,,,,,bool pending2,bool approved2) = onboardProposal.getProposal(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }


    function testProposePoolAfterSuccessfulProposal() public {
        // after a succesful proposal, a new pool proposal should not be possible
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR);
        vm.prank(bob);
        onboardProposal.vote(1, VOTE_FOR);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_FOR);
        vm.warp(260000);
        onboardProposal.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        onboardProposal.evaluatePoolProposalVotes(1);
        (,,,,,,,,bool pending,bool approved) = onboardProposal.getProposal(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Protocol already proposed");
        onboardProposal.propose(address(yeti), "Yeti", 10000, 1);
    }



    function testChangingPoolVotes() public {
        // initial voting period takes 3 days.
        // votes are evaluated and approval truthness is set.
        // for a day, more people can vote. If voting approval changes,
        // the voting period is extended by a day. else, proposal is sent to executor.
        // for a second day, more people can vote.
        // vote is definitive and proposal is sent to executor.
        vm.prank(alice);
        onboardProposal.vote(1, VOTE_FOR);

        vm.prank(bob);
        onboardProposal.vote(1, VOTE_AGAINST);
        
        vm.warp(260000);
        onboardProposal.evaluatePoolProposalVotes(1);
        (,,,,,,,,bool pending1,bool approved1) = onboardProposal.getProposal(1);
        // first evaluation finds that report is true
        assertEq(pending1 == true, true);
        assertEq(approved1 == true, true);
        vm.warp(350000);
        vm.prank(carol);
        onboardProposal.vote(1, VOTE_AGAINST);
        onboardProposal.evaluatePoolProposalVotes(1);
        (,,,,,,,,bool pending2,bool approved2) = onboardProposal.getProposal(1);
        // second evaluation finds that report is false
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
        vm.warp(500000);
        onboardProposal.vote(1, VOTE_FOR);
        onboardProposal.evaluatePoolProposalVotes(1);
        (,,,,,,,,bool pending3,bool approved3) = onboardProposal.getProposal(1);
        // third evaluation finds that report is true
        assertEq(pending3 == false, true);
        assertEq(approved3 == true, true);
    }
}