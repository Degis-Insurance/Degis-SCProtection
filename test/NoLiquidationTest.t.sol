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
        shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000000 ether, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);

        // deploy contracts
        reinsurancePool = new ReinsurancePool(
            address(deg),
            address(vedeg),
            address(shield)
        );
        insurancePoolFactory = new InsurancePoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(reinsurancePool)
        );
        policyCenter = new PolicyCenter(
            address(deg),
            address(vedeg),
            address(shield),
            address(reinsurancePool)
        );
        executor = new Executor();
        onboardProposal = new OnboardProposal(address(deg),
            address(vedeg),
            address(shield));
        incidentReport = new IncidentReport(address(deg),
            address(vedeg),
            address(shield));

        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000 ether);
        shield.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);

        insurancePoolFactory.setPolicyCenter(address(policyCenter));
     
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setExecutor(address(executor));

        reinsurancePool.setPolicyCenter(address(policyCenter));
        
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setPolicyCenter(address(policyCenter));

        policyCenter.setExecutor(address(executor));
       
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));

        onboardProposal.setExecutor(address(executor));
        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));


        incidentReport.setPolicyCenter(address(policyCenter));
        incidentReport.setReinsurancePool(address(reinsurancePool));
        incidentReport.setInsurancePoolFactory(address(insurancePoolFactory));

        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            260
        );

        InsurancePool(pool1).setExecutor(address(executor));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
       
        deg.transfer(address(this), 1000 ether);
        deg.transfer(address(policyCenter), 100);
        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 2000 ether);
        vedeg.transfer(carol, 3000 ether);
        // mint and approve tokens for pool1 and pool2
        ptp.approve(address(policyCenter), 10000 ether);
        yeti.approve(address(policyCenter), 10000 ether);

        // transfer shield to liquidity providers
        shield.transfer(alice, 100 ether);
        shield.transfer(bob, 100 ether);
        shield.transfer(carol, 100 ether);

        // transfer deg to users
        deg.transfer(alice, 10 ether);
        deg.transfer(bob, 10 ether);
        deg.transfer(carol, 10 ether);

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
        shield.approve(address(policyCenter), 1000000 ether);

        // carol buys coverage from pool 1
        uint256 price = InsurancePool(pool1).coveragePrice(10 ether, 90);
        vm.prank(carol);
        ptp.approve(address(policyCenter), 1000000 ether);
        vm.prank(carol);
        policyCenter.buyCoverage(1, price, 10 ether, 90);
        vm.warp(30 days);
    }

    function testClaimRewardsFromReinsurancePool() public {
        // bob should receive rewards from reinsurance pool
        vm.prank(bob);
        uint256 reward = policyCenter.calculateReward(0, bob);
        console.log("reward", reward);

        vm.prank(bob);
        policyCenter.claimReward(0);
        assertEq(reward > 0, true);
    }

    function testClaimRewardsFromInsurancePool() public {
        // alice should receive rewards from pool 1
        vm.prank(alice);
        (bool paused, , , , , ) = policyCenter.getPoolInfo(1);
        assertEq(paused, false);
        uint256 reward = policyCenter.calculateReward(1, alice);
        console.log("reward", reward);
        vm.prank(alice);
        policyCenter.claimReward(1);
        assertEq(reward > 0, true);
    }
}
