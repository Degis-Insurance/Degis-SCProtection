// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ReinsurancePool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/ProposalCenter.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/ReinsurancePoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IProposalCenter.sol";
import "src/interfaces/IComittee.sol";
import "src/interfaces/IExecutor.sol";

contract ProposalCenterTest is Test {

    InsurancePoolFactory public ipf;
    ReinsurancePool public rp;
    PolicyCenter public policyc;
    ProposalCenter public proposalc;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public e;

    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    address public ptp = address(0x133704);
    address public yeti = address(0x133705);
    address public pool1;

function setUp() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        policyc = new PolicyCenter(address(rp));
        e = new Executor();
        proposalc = new ProposalCenter();
        ipf.setDeg(address(deg));
        ipf.setVeDeg(address(vedeg));
        ipf.setShield(address(shield));
        ipf.setPolicyCenter(address(policyc));
        ipf.setProposalCenter(address(proposalc));
        ipf.setReinsurancePool(address(rp));
        ipf.setPolicyCenter(address(policyc));
        policyc.setDeg(address(deg));
        policyc.setVeDeg(address(vedeg));
        policyc.setShield(address(shield));
        policyc.setExecutor(address(e));
        policyc.setProposalCenter(address(proposalc));
        policyc.setReinsurancePool(address(rp));
        policyc.setInsurancePoolFactory(address(ipf));
        rp.setDeg(address(deg));
        rp.setVeDeg(address(vedeg));
        rp.setShield(address(shield));
        rp.setPolicyCenter(address(policyc));
        rp.setProposalCenter(address(proposalc));
        rp.setPolicyCenter(address(policyc));
        proposalc.setDeg(address(deg));
        proposalc.setVeDeg(address(vedeg));
        proposalc.setShield(address(shield));
        proposalc.setExecutor(address(e));
        proposalc.setPolicyCenter(address(policyc));
        proposalc.setReinsurancePool(address(rp));
        proposalc.setInsurancePoolFactory(address(ipf));
        e.setDeg(address(deg));
        e.setVeDeg(address(vedeg));
        e.setShield(address(shield));
        e.setPolicyCenter(address(policyc));
        e.setProposalCenter(address(proposalc));
        e.setReinsurancePool(address(rp));
        e.setInsurancePoolFactory(address(ipf));
        pool1 = ipf.deployPool("insurance", ptp, uint256(10000), uint256(1));
    }

    function testSetBufffers() public {
        proposalc.setBuffers(4 days, 4 days);
        assertEq(proposalc.reportBuffer() ==  4 days, true);
        assertEq(proposalc.proposalBuffer() ==  4 days, true);
    }
    
    function testProposePool() public {
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        (string memory protocolName,
        address protocolAddress,,,,,,,,,) = proposalc.getPoolProposal(1);
        console.log(protocolName);
        assertEq(protocolAddress == yeti, true);
    }

    function testReportPool() public {
        deg.transfer(address(this), 1000);
        deg.approve(address(proposalc), 1000e18);
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        proposalc.reportPool(1);
        
        (,,address reporterAddress,,, bool pending ,bool approved,) = proposalc.getReport(1);
        assertEq(reporterAddress == address(this), true);
        assertEq(pending == true, true);
        assertEq(approved == false, true);
    }

    function testSetPoolReportedByOwner() public {
        proposalc.setPoolReported(ptp, true);
        assertEq(proposalc.poolReported(ptp) == true, true);
    }

    function setProposal() public {
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        proposalc.setProposal(1, true);
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(2);
        assertEq( approved == true, true);
    }   
}

contract ProposalCenterVotingTest is Test {

    InsurancePoolFactory public ipf;
    ReinsurancePool public rp;
    PolicyCenter public policyc;
    ProposalCenter public proposalc;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public e;

    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    address public ptp = address(0x133704);
    address public yeti = address(0x133705);
    address public pool1;

    function setUp() public {
        shield = new MockSHIELD(10000000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        policyc = new PolicyCenter(address(rp));
        e = new Executor();
        proposalc = new ProposalCenter();
        vm.label(address(proposalc), "Proposal Center");
        ipf.setDeg(address(deg));
        ipf.setVeDeg(address(vedeg));
        ipf.setShield(address(shield));
        ipf.setPolicyCenter(address(policyc));
        ipf.setProposalCenter(address(proposalc));
        ipf.setReinsurancePool(address(rp));
        ipf.setPolicyCenter(address(policyc));
        rp.setDeg(address(deg));
        rp.setVeDeg(address(vedeg));
        rp.setShield(address(shield));
        rp.setPolicyCenter(address(policyc));
        rp.setProposalCenter(address(proposalc));
        rp.setPolicyCenter(address(policyc));
        policyc.setDeg(address(deg));
        policyc.setVeDeg(address(vedeg));
        policyc.setShield(address(shield));
        policyc.setExecutor(address(e));
        policyc.setProposalCenter(address(proposalc));
        policyc.setReinsurancePool(address(rp));
        policyc.setInsurancePoolFactory(address(ipf));
        proposalc.setDeg(address(deg));
        proposalc.setVeDeg(address(vedeg));
        proposalc.setShield(address(shield));
        proposalc.setExecutor(address(e));
        proposalc.setPolicyCenter(address(policyc));
        proposalc.setReinsurancePool(address(rp));
        proposalc.setInsurancePoolFactory(address(ipf));
        e.setDeg(address(deg));
        e.setVeDeg(address(vedeg));
        e.setShield(address(shield));
        e.setPolicyCenter(address(policyc));
        e.setProposalCenter(address(proposalc));
        e.setReinsurancePool(address(rp));
        e.setInsurancePoolFactory(address(ipf));
        pool1 = ipf.deployPool("insurance", ptp, uint256(30000e18), uint256(1));
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyc));
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        InsurancePool(pool1).setInsurancePoolFactory(address(ipf));
        deg.transfer(address(this), 1000e18);
        deg.approve(address(proposalc), 10000e18);
        vedeg.transfer(alice, 4000e18);
        vedeg.transfer(bob, 2500e18);
        vedeg.transfer(carol, 2000e18);
        vedeg.transfer(ptp, 1000e18);
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        proposalc.reportPool(1);
        shield.transfer(alice, 3000e18);
    }

    function testVoteProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        (,,,address[] memory voted,,,,,,,) = proposalc.getPoolProposal(1);
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
        assertEq(aliceVoted == true, true);
        assertEq(bobVoted == true, true);
        assertEq(carolVoted == true, true);
    }

    function testVoteReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        assertEq(aliceVote == true, true);
        assertEq(bobVote == false, true);
        assertEq(carolVote == true, true);
    }

    function testVoteMoreThanOnceOnReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        proposalc.voteReport(1, true);
    }

    function testVoteMoreThanOnceOnPoolProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        proposalc.votePoolProposal(1, true);
    }

    function testEvaluateReportNotEnoughVotes() public {
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        vm.warp(604801);
        vm.prank(ptp);
        vm.expectRevert("Not enough votes");
        proposalc.evaluateReportVotes(1);
    }

    function testEvaluateReportTrue() public {
       vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        (,,,,,,bool approved,) = proposalc.getReport(1);
        assertEq(approved == true, true);
    }

    function testEvaluateReportFalse() public {
       vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, false);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        vm.warp(604801);
        vm.prank(ptp);
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(1);
        assertEq(approved == false, true);
    }

    function testEvaluatePoolProposalTrue() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(1);
        assertEq(approved == true, true);
    }

    function testEvaluatePoolProposalFalse() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, false);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);    
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(1);
        assertEq(approved == false, true); 
    }

    function testReportPoolAlreadyReported() public {
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalc), 1000e18);
        vm.prank(alice);
        vm.expectRevert("Pool already reported");
        proposalc.reportPool(1);
    }

    function testProposePooolAlreadyProposed() public {
        vm.prank(alice);
        vm.expectRevert("Protocol already proposed");
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
    }

    function testReportPoolAfterFailedReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, false);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, false);
        vm.warp(260000);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
         vm.warp(350000);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending1,bool approved1,) = proposalc.getReport(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        proposalc.reportPool(1);
        (,,,,,bool pending2,bool approved2,) = proposalc.getReport(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }

    function testProposePoolAfterFailedProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, false);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, false);
        vm.warp(260000);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        (,,,,,,,,,bool pending1,bool approved1) = proposalc.getPoolProposal(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        (,,,,,,,,,bool pending2,bool approved2) = proposalc.getPoolProposal(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }

    function testReportPoolAfterSuccessfulReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, true);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        vm.warp(260000);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        vm.warp(350000);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending,bool approved,) = proposalc.getReport(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Pool already reported");
        proposalc.reportPool(1);
    }

    function testProposePoolAfterSuccessfulProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, true);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        vm.warp(260000);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending,bool approved) = proposalc.getPoolProposal(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Protocol already proposed");
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
    }

    function testChangingReportVotes() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.warp(260000);
        vm.prank(yeti);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending1,bool approved1,) = proposalc.getReport(1);
        assertEq(pending1 == true, true);
        assertEq(approved1 == true, true);
        vm.warp(350000);
        vm.prank(carol);
        proposalc.voteReport(1, false);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending2,bool approved2,) = proposalc.getReport(1);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
        vm.warp(500000);
        vm.prank(ptp);
        proposalc.voteReport(1, true);
        vm.prank(yeti);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending3,bool approved3,) = proposalc.getReport(1);
        assertEq(pending3 == false, true);
        assertEq(approved3 == true, true);
    }

    function testChangingPoolVotes() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.warp(260000);
        vm.prank(yeti);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending1,bool approved1) = proposalc.getPoolProposal(1);
        assertEq(pending1 == true, true);
        assertEq(approved1 == true, true);
        vm.warp(350000);
        vm.prank(carol);
        proposalc.votePoolProposal(1, false);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending2,bool approved2) = proposalc.getPoolProposal(1);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
        vm.warp(500000);
        vm.prank(ptp);
        proposalc.votePoolProposal(1, true);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending3,bool approved3) = proposalc.getPoolProposal(1);
        assertEq(pending3 == false, true);
        assertEq(approved3 == true, true);
    }

    function testExecuteReportBeforeBeingQueued() public {
        vm.expectRevert("report not pending or not found");
        e.executeReport(1);
    }

    function testClaimRewardsFromLiquidityProvision() public {
        shield.transfer(carol, 5000e18);
        uint256 price = InsurancePool(pool1).coveragePrice(10000e18, 365);
        vm.prank(carol);
        shield.approve(address(policyc), 1000e18);
        vm.prank(carol);
        policyc.buyCoverage(1, price, 10000e18, 365);
        vm.warp(200);
        shield.transfer(alice, 5000e18);
        shield.transfer(bob, 5000e18);
        vm.prank(alice);
        shield.approve(address(policyc), 20000e18);
        vm.prank(alice);
        policyc.provideLiquidity(1, 5000e18);
        vm.prank(bob);
        shield.approve(address(policyc), 20000e18);
        vm.prank(bob);
        policyc.provideLiquidity(1, 5000e18);
        vm.prank(carol);
        shield.approve(address(policyc), 1000e18);
        vm.warp(30 days);
        vm.prank(alice);
        policyc.splitPremium(1);
        uint256 reward = InsurancePool(pool1).calculateReward(alice);
        console.log("reward", reward);
        vm.prank(alice);
        policyc.claimReward(1);
        assertEq(reward == 4, true);
    }
}