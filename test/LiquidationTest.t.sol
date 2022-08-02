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
import "src/voting/interfaces/IncidentReportParameters.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/ReinsurancePoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IComittee.sol";
import "src/interfaces/IExecutor.sol";

contract ClaimPayoutTest is Test, IncidentReportParameters {

    

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    Exchange public exchange;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;

    uint256 constant VOTE_FOR = 1;
    uint256 constant VOTE_AGAINST = 2;

    uint256 constant POOL_ID = 1;
    uint256 constant PROPOSAL_ID = 1;

    uint256 constant REPORT_START_TIME = 1000;

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
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000 ether);

        // deploy contracts
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        incidentReport = new IncidentReport();
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        onboardProposal = new OnboardProposal();

        // add incident report as a deg minter
        deg.addMinter(address(incidentReport));

        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000 ether);
        shield.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);
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
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setOnboardProposal(address(onboardProposal));
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
        deg.transfer(address(this), 1000 ether);
        deg.transfer(address(onboardProposal), 1000 ether);
        deg.approve(address(onboardProposal), 10000 ether);
        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 2000 ether);
        vedeg.transfer(carol, 3000 ether);

        // owner provides liquidity to pool 1
        shield.transfer(address(this), 1000);
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(1, 10000);

        uint256 price = InsurancePool(pool1).coveragePrice(100 ether, 90);
        ptp.approve(address(policyCenter), 100000 ether);
        policyCenter.buyCoverage(1, price, 100 ether, 90);

        vm.warp(REPORT_START_TIME);
        incidentReport.report(1);

         vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(1);

        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 2500 ether);
        vm.prank(bob);
        incidentReport.vote(1, VOTE_FOR, 2000 ether);
        vm.prank(carol);
        incidentReport.vote(1, VOTE_FOR, 1500 ether);

        vm.warp( REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);

        incidentReport.settle(POOL_ID);
        
        // TODO: execute pending pool
        executor.executeReport(1);
    }

    function testClaimPayout() public {
        // claim payout during claiming period
        vm.warp(15 days);
        uint256 amount = policyCenter.calculatePayout(1, address(this));
        policyCenter.claimPayout(1);
        console.log(amount);
    }
    
    function testClaimPayoutUnexsistentpool() public {
        vm.expectRevert("Pool not found");
        policyCenter.claimPayout(2);
    }

    function unpauseLiquidatedPool() public {
        InsurancePool(pool1).setPausedInsurancePool(false);
        assertEq(InsurancePool(pool1).liquidated() == false, true);
    }
}