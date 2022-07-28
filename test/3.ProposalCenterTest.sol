// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ReinsurancePool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/ProposalCenter.sol";
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
import "src/interfaces/IProposalCenter.sol";
import "src/interfaces/IComittee.sol";
import "src/interfaces/IExecutor.sol";

contract ProposalCenterTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
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
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        deg.approve(address(policyCenter), 10000e18);
        deg.transfer(address(this), 100e18);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000e18);

        deg.approve(address(this), 10000e18);
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100e18);
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
        proposalCenter = new ProposalCenter();
        exchange = new Exchange();

        // sets addresses needed to execute functions
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setProposalCenter(address(proposalCenter));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setExecutor(address(executor));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setProposalCenter(address(proposalCenter));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setProposalCenter(address(proposalCenter));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        proposalCenter.setDeg(address(deg));
        proposalCenter.setVeDeg(address(vedeg));
        proposalCenter.setShield(address(shield));
        proposalCenter.setExecutor(address(executor));
        proposalCenter.setPolicyCenter(address(policyCenter));
        proposalCenter.setReinsurancePool(address(reinsurancePool));
        proposalCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        executor.setDeg(address(deg));
        executor.setVeDeg(address(vedeg));
        executor.setShield(address(shield));
        executor.setPolicyCenter(address(policyCenter));
        executor.setProposalCenter(address(proposalCenter));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        //deploy ptp pool
        pool1 = insurancePoolFactory.deployPool("PTP", address(ptp), uint256(10000), uint256(1));
         // set addreses for ptp pool
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        InsurancePool(pool1).setReinsurancePool(address(reinsurancePool));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
    }

    function testSetProposalCenterBufffers() public {
        // proposal center buffer for voting period changes to 4 days
        proposalCenter.setBuffers(4 days, 4 days);
        assertEq(proposalCenter.reportBuffer() ==  4 days, true);
        assertEq(proposalCenter.proposalBuffer() ==  4 days, true);
    }
    
    function testProposePool() public {
        // propose a yeti pool
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        (string memory protocolName,
        address protocolAddress,,,,,,,,,) = proposalCenter.getPoolProposal(1);
        console.log(protocolName);
        // proposal is recorded
        assertEq(protocolAddress == address(yeti), true);
    }

    function testReportPool() public {
        // approve then report ptp pool
        deg.transfer(address(this), 1000);
        deg.approve(address(proposalCenter), 1000e18);
        proposalCenter.reportPool(1);
        // verify that pool has been reported and report has been registered
        (,,address reporterAddress,,, bool pending ,bool approved,) = proposalCenter.getReport(1);
        assertEq(reporterAddress == address(this), true);
        assertEq(pending == true, true);
        assertEq(approved == false, true);
    }

    function testSetPoolReported() public {
        // approve then report ptp pool by alice
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalCenter), 1000e18);
        // report pool by alice
        vm.prank(alice);
        proposalCenter.reportPool(1);
        // set pool as not reported. only owner
        proposalCenter.setPoolReported(address(ptp), false);
        assertEq(proposalCenter.poolReported(address(ptp)) == false, true);
    }

    function testSetPoolReportedNotOwner() public {
        // approve then report ptp pool by alice
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalCenter), 1000e18);
        // report pool by alice
        vm.prank(alice);
        proposalCenter.reportPool(1);
        // set pool as not reported. only owner
        vm.prank(alice);
        vm.expectRevert("Only owner or executor can call this function");
        proposalCenter.setPoolReported(address(ptp), false);
    }

    function testSetPoolProposed() public {
        // set pooll as proposed. only owner
        proposalCenter.setPoolProposed(address(yeti), true);
        assertEq(proposalCenter.poolProposed(address(yeti)) == true, true);
    }

    function testSetPoolProposedNotByOwner() public {
        // set pooll as proposed. only owner
        vm.prank(alice);
        vm.expectRevert("Only owner or executor can call this function");
        proposalCenter.setPoolProposed(address(yeti), true);
    }

    function setReportStatus() public {
         // approve then report ptp pool by alice
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalCenter), 1000e18);
        vm.prank(alice);
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        // report pool by alice
        vm.prank(alice);
        proposalCenter.reportPool(1);
        proposalCenter.setReportApproval(1, true);
        (,,,,,,,,,,bool approved) = proposalCenter.getPoolProposal(1);
        assertEq( approved == true, true);
    }   

    function setProposalStatus() public {
        // change proposal status by owner
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        proposalCenter.setProposalApproval(1, true);
        (,,,,,,,,,,bool approved) = proposalCenter.getPoolProposal(1);
        assertEq( approved == true, true);
    }

    function setReportStatusNotByOwner() public {
         // approve then report ptp pool by alice
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalCenter), 1000e18);
        vm.prank(alice);
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        // report pool by alice
        vm.prank(alice);
        proposalCenter.reportPool(1);
        vm.prank(alice);
        // non owner should not be able to set proposal status
        vm.expectRevert("Only owner or executor can call this function");
        proposalCenter.setReportApproval(1, true);
    }   

    function setProposalStatusNotByOwner() public {
        // non owner should not be able to set proposal status
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        vm.prank(alice);
        vm.expectRevert("Only owner or executor can call this function");
        proposalCenter.setProposalApproval(1, true);
    }    
}

contract ProposalCenterVotingTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public executor;
    Exchange public exchange;
    ERC20 public ptp;
    ERC20 public yeti;

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;

    function setUp() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);
        vedeg = new MockVeDEG(10000e18, "VeDEG", 18, "VEDEG");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        deg.approve(address(policyCenter), 10000e18);
        deg.transfer(address(this), 100e18);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000e18);
        // 
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
        proposalCenter = new ProposalCenter();
        exchange = new Exchange();

        vm.label(address(proposalCenter), "Proposal Center");
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setExecutor(address(executor));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setProposalCenter(address(proposalCenter));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setExecutor(address(executor));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setProposalCenter(address(proposalCenter));
        reinsurancePool.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setExchange(address(exchange));
        policyCenter.setProposalCenter(address(proposalCenter));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        proposalCenter.setDeg(address(deg));
        proposalCenter.setVeDeg(address(vedeg));
        proposalCenter.setShield(address(shield));
        proposalCenter.setExecutor(address(executor));
        proposalCenter.setPolicyCenter(address(policyCenter));
        proposalCenter.setReinsurancePool(address(reinsurancePool));
        proposalCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        executor.setDeg(address(deg));
        executor.setVeDeg(address(vedeg));
        executor.setShield(address(shield));
        executor.setPolicyCenter(address(policyCenter));
        executor.setProposalCenter(address(proposalCenter));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        // create insurance pool
        pool1 = insurancePoolFactory.deployPool("PTP", address(ptp), 10000e18, 1);
        console.log(pool1);
        // set insurance pool addresses
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));

        deg.transfer(address(this), 1000e18);
        deg.approve(address(proposalCenter), 10000e18);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 1500e18);
        vedeg.transfer(carol, 1600e18);
        vedeg.transfer(address(this), 1000e18);
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        proposalCenter.reportPool(1);
        shield.transfer(alice, 3000e18);
    }

    function testVoteProposal() public {
        // vote with 3 participants 
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, false);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, true);
        (,,,address[] memory voted,,,,,,,) = proposalCenter.getPoolProposal(1);
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

    function testVoteReport() public {
        vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(bob);
        proposalCenter.voteReport(1, false);
        vm.prank(carol);
        proposalCenter.voteReport(1, true);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalCenter.confirmsReport(1,alice);
        bobVote = proposalCenter.confirmsReport(1,bob);
        carolVote = proposalCenter.confirmsReport(1,carol);
        // check if votes are recorded
        assertEq(aliceVote == true, true);
        assertEq(bobVote == false, true);
        assertEq(carolVote == true, true);
    }

    function testVoteMoreThanOnceOnReport() public {
        // user should not be able to vote twice
        vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        proposalCenter.voteReport(1, true);
    }

    function testVoteMoreThanOnceOnPoolProposal() public {
        // user should not be able to vote twice
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        proposalCenter.votePoolProposal(1, true);
    }

    function testEvaluateReportNotEnoughVotes() public {
        // proposal should only pass if at least 30% of vedeg has participated in the vote
        // vm.prank(bob);
        // proposalCenter.voteReport(1, false);
        vm.prank(carol);
        proposalCenter.voteReport(1, true);
        vm.warp(604801);
        vm.expectRevert("Not enough votes");
        proposalCenter.evaluateReportVotes(1);
    }

    function testEvaluateReportTrue() public {
        // report should be truthy if majority of votes are true
       vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(bob);
        proposalCenter.voteReport(1, false);
        vm.prank(carol);
        proposalCenter.voteReport(1, true);
        vm.warp(604801);
        vm.prank(address(0x11133159));
        proposalCenter.evaluateReportVotes(1);
        (,,,,,,bool approved,) = proposalCenter.getReport(1);
        assertEq(approved == true, true);
    }

    function testEvaluateReportFalse() public {
        // report should be false if majority of votes are false
       vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(bob);
        proposalCenter.voteReport(1, false);
        vm.prank(carol);
        proposalCenter.voteReport(1, false);
        vm.warp(604801);
        vm.prank(address(0x11133159));
        (,,,,,,,,,,bool approved) = proposalCenter.getPoolProposal(1);
        assertEq(approved == false, true);
    }

    function testEvaluatePoolProposalTrue() public {
        // pool proposal should be truthy if majority of votes are true
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, false);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, true);
        vm.warp(604801);
        vm.prank(address(0x11133159));
        proposalCenter.evaluatePoolProposalVotes(1);
        (,,,,,,,,,,bool approved) = proposalCenter.getPoolProposal(1);
        assertEq(approved == true, true);
    }

    function testEvaluatePoolProposalFalse() public {
        // pool proposal should be false if majority of votes are false
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, false);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, false);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, true);
        vm.warp(604801);
        vm.prank(address(0x11133159));
        proposalCenter.evaluatePoolProposalVotes(1);    
        (,,,,,,,,,,bool approved) = proposalCenter.getPoolProposal(1);
        assertEq(approved == false, true); 
    }

    function testReportPoolAlreadyReported() public {
        // report should not reported twice
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalCenter), 1000e18);
        vm.prank(alice);
        vm.expectRevert("Pool already reported");
        proposalCenter.reportPool(1);
    }

    function testProposePooolAlreadyProposed() public {
        // pool proposal should not be proposed twice
        vm.prank(alice);
        vm.expectRevert("Protocol already proposed");
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
    }

    function testReportPoolAfterFailedReport() public {
        // after a failed report, a new report should be possible
        vm.prank(alice);
        proposalCenter.voteReport(1, false);
        vm.prank(bob);
        proposalCenter.voteReport(1, false);
        vm.prank(carol);
        proposalCenter.voteReport(1, false);
        vm.warp(260000);
        vm.prank(address(0x11133159));
        // evaluate report round 0
        proposalCenter.evaluateReportVotes(1);
         vm.warp(350000);
        vm.prank(address(0x11133159));
        // evaluate report round 1: approval did not change, report moves on.
        proposalCenter.evaluateReportVotes(1);
        (,,,,,bool pending1,bool approved1,) = proposalCenter.getReport(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        proposalCenter.reportPool(1);
        (,,,,,bool pending2,bool approved2,) = proposalCenter.getReport(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }

    function testProposePoolAfterFailedProposal() public {
        // after a failed proposal, a new proposal should be possible
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, false);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, false);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, false);
        vm.warp(260000);
        vm.prank(address(0x11133159));
        // evaluate proposal round 0
        proposalCenter.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        vm.prank(address(0x11133159));
        // evaluate proposal round 1: approval did not change, proposal moves on.
        proposalCenter.evaluatePoolProposalVotes(1);
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        // pool proposal is not pending and was false.
        (,,,,,,,,,bool pending1,bool approved1) = proposalCenter.getPoolProposal(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        // new pool proposal is pending and is still not approved
        (,,,,,,,,,bool pending2,bool approved2) = proposalCenter.getPoolProposal(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }

    function testReportPoolAfterSuccessfulReport() public {
        // after a succesful report, a new report should not be possible
        vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(bob);
        proposalCenter.voteReport(1, true);
        vm.prank(carol);
        proposalCenter.voteReport(1, true);
        vm.warp(260000);
        vm.prank(address(0x11133159));
        proposalCenter.evaluateReportVotes(1);
        vm.warp(350000);
        vm.prank(address(0x11133159));
        proposalCenter.evaluateReportVotes(1);
        (,,,,,bool pending,bool approved,) = proposalCenter.getReport(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Pool already reported");
        proposalCenter.reportPool(1);
    }

    function testProposePoolAfterSuccessfulProposal() public {
        // after a succesful proposal, a new pool proposal should not be possible
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, true);
        vm.warp(260000);
        proposalCenter.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        proposalCenter.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending,bool approved) = proposalCenter.getPoolProposal(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Protocol already proposed");
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
    }

    function testChangingReportVotes() public {
        // initial voting period takes 3 days.
        // votes are evaluated and approval truthness is set.
        // for a day, more people can vote. If voting approval changes,
        // the voting period is extended by a day. else, report is sent to executor.
        // for a second day, more people can vote.
        // vote is definitive and report is sent to executor.
        vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(bob);
        proposalCenter.voteReport(1, false);
        vm.warp(260000);
        proposalCenter.evaluateReportVotes(1);
        (,,,,,bool pending1,bool approved1,) = proposalCenter.getReport(1);
        // first evaluation finds that report is true
        assertEq(pending1 == true, true);
        assertEq(approved1 == true, true);
        vm.warp(350000);
        vm.prank(carol);
        proposalCenter.voteReport(1, false);
        proposalCenter.evaluateReportVotes(1);
        (,,,,,bool pending2,bool approved2,) = proposalCenter.getReport(1);
        // second evaluation finds that report is false
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
        vm.warp(500000);
        proposalCenter.voteReport(1, true);
        proposalCenter.evaluateReportVotes(1);
        (,,,,,bool pending3,bool approved3,) = proposalCenter.getReport(1);
        // third evaluation finds that report is true
        assertEq(pending3 == false, true);
        assertEq(approved3 == true, true);
    }

    function testChangingPoolVotes() public {
        // initial voting period takes 3 days.
        // votes are evaluated and approval truthness is set.
        // for a day, more people can vote. If voting approval changes,
        // the voting period is extended by a day. else, proposal is sent to executor.
        // for a second day, more people can vote.
        // vote is definitive and proposal is sent to executor.
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, false);
        vm.warp(260000);
        proposalCenter.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending1,bool approved1) = proposalCenter.getPoolProposal(1);
        // first evaluation finds that report is true
        assertEq(pending1 == true, true);
        assertEq(approved1 == true, true);
        vm.warp(350000);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, false);
        proposalCenter.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending2,bool approved2) = proposalCenter.getPoolProposal(1);
        // second evaluation finds that report is false
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
        vm.warp(500000);
        proposalCenter.votePoolProposal(1, true);
        proposalCenter.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending3,bool approved3) = proposalCenter.getPoolProposal(1);
        // third evaluation finds that report is true
        assertEq(pending3 == false, true);
        assertEq(approved3 == true, true);
    }

    function testExecuteReportBeforeBeingQueued() public {
        // a report should only be executable once its queued in the executor
        vm.expectRevert("report not pending or not found");
       executor.executeReport(1);
    }
}