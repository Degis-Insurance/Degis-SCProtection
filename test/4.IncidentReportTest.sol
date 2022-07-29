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
import "src/interfaces/IProposalCenter.sol";
import "src/interfaces/IComittee.sol";
import "src/interfaces/IExecutor.sol";

contract IncidentReportTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
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
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        deg.approve(address(policyCenter), 10000e18);
        deg.transfer(address(this), 100e18);
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100e18);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000e18);

        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
        proposalCenter = new ProposalCenter();
        exchange = new Exchange();
        IncidentReport = new IncidentReport();
        
        // approve incident report interaction
        deg.approve(address(incidentReport), 10000e18);
        vedeg.approve(address(incidentReport), 10000e18);
        ptp.approve(address(incidentReport), 10000e18);

        vedeg.transfer(alice, 2500e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 1500e18);

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

        incidentReport.report(1);
    }


    function testVoteReport() public {
        vm.prank(alice);
        incidentReport.vote(1, 1, 2500e18);
        vm.prank(bob);
        incidentReport.vote(1, 2, 2000e18);
        vm.prank(carol);
        incidentReport.vote(1, 1, 1500e18);
        (uint256 aliceVote,,,) = incidentReport.getUserVote(alice, 1);
        (uint256 bobVote,,,) = incidentReport.getUserVote(bob, 1);
        (uint256 carolVote,,,) = incidentReport.getUserVote(carol, 1);
        // check if votes are recorded
        assertEq(aliceVote == true, true);
        assertEq(bobVote == false, true);
        assertEq(carolVote == true, true);
    }

    function testVoteMoreThanOnceOnReport() public {
        // user should not be able to vote twice
        vm.prank(alice);
        incidentReport.vote(1, 1, 2500e18);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        incidentReport.vote(1, true);
    }


    function testEvaluateReportNotEnoughVotes() public {
        // proposal should only pass if at least 30% of vedeg has participated in the vote
        // vm.prank(bob);
        //  incidentReport.vote(1, false);
        vm.prank(carol);
         incidentReport.vote(1, 1, 1500e18);
        vm.warp(604801);
        vm.expectRevert("Not enough votes");
         incidentReport.evaluateReportVotes(1);
    }

    function testEvaluateReportTrue() public {
        // report should be truthy if majority of votes are true
         vm.prank(alice);
        incidentReport.vote(1, 1, 2500e18);
        vm.prank(bob);
        incidentReport.vote(1, 2, 2000e18);
        vm.prank(carol);
        incidentReport.vote(1, 1, 1500e18);
        vm.warp(604801);
        vm.prank(address(0x11133159));
         incidentReport.evaluateReportVotes(1);
        (,,,,,,bool approved,) =  incidentReport.getReport(1);
        assertEq(approved == 1, true);
    }

    function testEvaluateReportFalse() public {
        // report should be false if majority of votes are false
        vm.prank(alice);
        incidentReport.vote(1, 1, 2500e18);
        vm.prank(bob);
        incidentReport.vote(1, 2, 2000e18);
        vm.prank(carol);
        incidentReport.vote(1, 2, 1500e18);
        vm.warp(604801);
        (uint256 result,,) =  incidentReport.getTempResult(1);
        assertEq(result == 2, true);
    }

    function testReportPoolAfterFailedReport() public {
        // after a failed report, a new report should be possible
         vm.prank(alice);
        incidentReport.vote(1, 1, 2500e18);
        vm.prank(bob);
        incidentReport.vote(1, 2, 2000e18);
        vm.prank(carol);
        incidentReport.vote(1, 2, 1500e18);
        vm.warp(260000);
        // evaluate report round 0
        incidentReport.settle(1);
        vm.warp(350000);
        // evaluate report round 1: approval did not change, report moves on.
        (uint256 result1,,) =  incidentReport.getTempResult(1);
        assertEq(result1 == 2, true);
        incidentReport.settle(1);
        (,,,,,,,uint256 status,uint256 result2,) =  incidentReport.getReport(1);
        assertEq(status == 1, true);
        assertEq(result2 == 2, true);
        incidentReport.report(1);
    }

    function testReportPoolAfterSuccessfulReport() public {
        // after a succesful report, a new report should not be possible
        vm.prank(alice);
         incidentReport.vote(1, true);
        vm.prank(bob);
         incidentReport.vote(1, true);
        vm.prank(carol);
         incidentReport.vote(1, true);
        vm.warp(260000);
        vm.prank(address(0x11133159));
         incidentReport.settle(1);
        vm.warp(350000);
        vm.prank(address(0x11133159));
         incidentReport.settle(1);
        (,,,,,bool pending,bool approved,) =  incidentReport.getReport(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Pool already reported");
         incidentReport.reportPool(1);
    }

    function testChangingReportVotes() public {
        // initial voting period takes 3 days.
        // votes are evaluated and approval truthness is set.
        // for a day, more people can vote. If voting approval changes,
        // the voting period is extended by a day. else, report is sent to executor.
        // for a second day, more people can vote.
        // vote is definitive and report is sent to executor.
        vm.prank(alice);
         incidentReport.vote(1, true);
        vm.prank(bob);
         incidentReport.vote(1, false);
        vm.warp(260000);
         incidentReport.settle(1);
        (,,,,,bool pending1,bool approved1,) = incidentReport.getReport(1);
        // first evaluation finds that report is true
        assertEq(pending1 == true, true);
        assertEq(approved1 == true, true);
        vm.warp(350000);
        vm.prank(carol);
         incidentReport.vote(1, false);
         incidentReport.settle(1);
        (,,,,,bool pending2,bool approved2,) = incidentReport.getReport(1);
        // second evaluation finds that report is false
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
        vm.warp(500000);
         incidentReport.vote(1, true);
         incidentReport.settle(1);
        (,,,,,bool pending3,bool approved3,) = incidentReport.getReport(1);
        // third evaluation finds that report is true
        assertEq(pending3 == false, true);
        assertEq(approved3 == true, true);
    }

    function testExecuteReportBeforeBeingQueued() public {
        // a report should only be executable once its queued in the executor
        vm.expectRevert("report not pending or not found");
       executor.settle(1);
    }
}