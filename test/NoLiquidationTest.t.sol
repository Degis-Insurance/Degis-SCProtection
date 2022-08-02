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

contract NoLiquidationTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    IncidentReport public incidentReport;
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
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000 ether);

        // deploy contracts
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
        onboardProposal = new OnboardProposal();
        incidentReport = new IncidentReport();
        

        // add incident report as minter to burn and mint tokens
        // on the ecosystem's behalf
        deg.addMinter(address(incidentReport));

        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000e18);
        shield.transfer(address(exchange), 1000e18);
        ptp.transfer(address(exchange), 1000e18);
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setOnboardProposal(address(onboardProposal));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setExecutor(address(executor));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setOnboardProposal(address(onboardProposal));
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setOnboardProposal(address(onboardProposal));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        onboardProposal.setDeg(address(deg));
        onboardProposal.setVeDeg(address(vedeg));
        onboardProposal.setShield(address(shield));
        onboardProposal.setExecutor(address(executor));
        onboardProposal.setPolicyCenter(address(policyCenter));
        onboardProposal.setReinsurancePool(address(reinsurancePool));
        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));
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
        pool1 = insurancePoolFactory.deployPool("Platypus", address(ptp), 1000 ether, 1);
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setExecutor(address(executor));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
        deg.transfer(address(this), 1000e18);
        deg.transfer(address(policyCenter), 100);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 3000e18);
         // mint and approve tokens for pool1 and pool2
        ptp.approve(address(policyCenter), 10000 ether);
        yeti.approve(address(policyCenter), 10000 ether);

        // transfer shield to liquidity providers
        shield.transfer(alice, 100 ether);
        shield.transfer(bob, 100 ether);
        shield.transfer(carol, 100 ether);

        // transfer deg to users
        deg.transfer(alice, 10e18);
        deg.transfer(bob, 10e18);
        deg.transfer(carol, 10e18);

        // transfer ptp to carol
        // to buy coverage
        ptp.transfer(carol, 100 ether);
        // approve ptp usage for carol
        vm.prank(carol);
        ptp.approve(address(policyCenter), 1000000 ether);

        // provide liquidity by users
        // alice provides liquidity to pool 1
        vm.prank(alice);
        shield.approve(address(policyCenter), 10000 ether);
        vm.prank(alice);
        policyCenter.provideLiquidity(1, 1 ether);

        // bob provides liqudity to reinsurance pool
        vm.prank(bob);
        shield.approve(address(policyCenter), 10000 ether);
        vm.prank(bob);
        policyCenter.provideLiquidity(0, 1 ether);
        vm.prank(carol);
        shield.approve(address(policyCenter), 1000000e18);

        // carol buys coverage from pool 1
        uint256 price = InsurancePool(pool1).coveragePrice(10 ether, 90);
        vm.prank(carol);
        ptp.approve(address(policyCenter), 1000000e18);
        vm.prank(carol);
        policyCenter.buyCoverage(1, price, 10 ether, 90);
        vm.warp(30 days);
    }

    function testClaimRewardsFromReinsurancePool() public {
        // bob should receive rewards from reinsurance pool
        vm.prank(bob);
        uint256 reward = policyCenter.calculateReward(0, alice);
        console.log("reward", reward);
        vm.prank(bob);
        policyCenter.claimReward(0);
        assertEq(reward > 0, true);
    }

    function testClaimRewardsFromInsurancePool() public {
        // alice should receive rewards from pool 1
        vm.prank(alice);
        (,address insuredToken ,,,) = policyCenter.getPoolInfo(1);
        console.log(insuredToken);
        assertEq(insuredToken == address(ptp), true);
        uint256 reward = policyCenter.calculateReward(1, alice);
        console.log("reward", reward);
        vm.prank(alice);
        policyCenter.claimReward(1);
        assertEq(reward > 0, true);
    }

}