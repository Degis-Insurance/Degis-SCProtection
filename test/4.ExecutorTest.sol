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

contract ExecutorTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Exchange public exchange;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;
    address public pool2;

    function setUp() public {
        shield = new MockSHIELD(10000000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000e18);
        
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        proposalCenter = new ProposalCenter();
        deg.addMinter(address(proposalCenter));
        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000e18);
        shield.transfer(address(exchange), 1000e18);
        ptp.transfer(address(exchange), 1000e18);

        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setProposalCenter(address(proposalCenter));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setExecutor(address(executor));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setProposalCenter(address(proposalCenter));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setExecutor(address(executor));
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setProposalCenter(address(proposalCenter));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
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
        pool1 = insurancePoolFactory.deployPool("insurance", address(ptp), uint256(10000), uint256(1));
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setExecutor(address(executor));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
        deg.transfer(address(this), 1000e18);
        deg.transfer(address(proposalCenter), 1000e18);
        deg.approve(address(proposalCenter), 10000e18);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 3000e18);
        shield.transfer(address(this), 1000e18);
        shield.approve(address(policyCenter), 10000e18);
        // mint and approve tokens for pool1 and pool2
        ptp.approve(address(policyCenter), 10000e18);
        yeti.approve(address(policyCenter), 10000e18);

        policyCenter.provideLiquidity(1, 10000);
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        proposalCenter.reportPool(1);
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(alice);
        proposalCenter.voteReport(1, true);
        vm.prank(bob);
        proposalCenter.voteReport(1, true);
        vm.prank(carol);
        proposalCenter.voteReport(1, true);
        vm.warp(260000);
        proposalCenter.evaluateReportVotes(1);
        proposalCenter.evaluatePoolProposalVotes(1);
        vm.warp(350000);
        // pass pool1 report to executor
        proposalCenter.evaluateReportVotes(1);
        // pass yeti pool proposal to executor
        proposalCenter.evaluatePoolProposalVotes(1);
    }

    function testGetPendingPools() public {
        // retrieves pending pool by id
        // should return its state
        (uint256 poolId,, bool pending, bool approved) =executor.queuedReportsById(1);
        assertEq(poolId == 1, true);
        assertEq(pending == true, true);
        assertEq(approved == true, true);
    }

    function testExecuteReportPriorToBuffer() public {
        // report should not be executable prior to time buffer
        vm.expectRevert("report not ready");
       executor.executeReport(1);
    }

    function testExecutePoolPriorToBuffer() public {
        // report should not be executable prior to time buffer
        vm.expectRevert("pool not ready");
       executor.executeNewPool(1);
    }

    function testExecuteReportAfterBuffer() public {
        // report should be executable after time buffer
        vm.warp(1000000);
        executor.executeReport(1);
        assertEq(InsurancePool(pool1).liquidated()  == true, true);
    }

    function testExecutePoolAfterBuffer() public {
        // pool should be executable after time buffer
        vm.warp(1000000);
        address newPool = executor.executeNewPool(1);
        address[] memory addresses = insurancePoolFactory.getPoolAddressList();
        address registeredNewPool = addresses[addresses.length - 1];
        assertEq(newPool == registeredNewPool, true);
    }

    function testExecuteReportNotOwner() public {
        // only owner aka manager can execute a report
        vm.warp(1000000);
        vm.prank(carol);
        vm.expectRevert("Ownable: caller is not the owner");
       executor.executeReport(1);
    }

    function testExecutePoolNotOwner() public {
        // only owner aka manager can execute a new pool
        vm.warp(1209602);
        vm.prank(carol);
        vm.expectRevert("Ownable: caller is not the owner");
       executor.executeNewPool(1);
    }

    function testCancelReport() public {
        // owner should be able to cancel a report
        vm.warp(1000000);
       executor.cancelReport(1);
        (uint256 poolId,, bool pending, bool approved) =executor.queuedReportsById(1);
        bool truthy = InsurancePool(pool1).liquidated();
        assertEq(poolId == 1, true);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        assertEq(truthy == false, true);
    }

    function testCancelPool() public {
        // owner should be able to cancel a new pool proposal
        vm.warp(1209602);
        executor.cancelNewPool(1);
        (,,,,, bool pending,) =executor.queuedPoolsById(1);
        assertEq(pending == false, true);
    }

    function testCancelReportNotOwner() public {
        // users should not be able to cancel a report
        vm.warp(1000000);
        vm.prank(carol);
        vm.expectRevert("Ownable: caller is not the owner");
        executor.cancelReport(1);  
    }

    function testCancelPoolNotOwner() public {
        // users should not be able to cancel a prposal
        vm.warp(1209602);
        vm.prank(carol);
        vm.expectRevert("Ownable: caller is not the owner");
        executor.cancelNewPool(1);
    }
}

