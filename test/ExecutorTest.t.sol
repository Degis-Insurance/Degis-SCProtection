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

contract ExecutorTest is Test,IncidentReportParameters {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
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
        
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(
            address(reinsurancePool),
            address(deg)
        );
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        onboardProposal = new OnboardProposal();
        incidentReport = new IncidentReport();
        deg.addMinter(address(onboardProposal));
        // deploy exchange and supply tokens so that they 
        // can be swapped when coverage is bought and split among pools
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
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setOnboardProposal(address(onboardProposal));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setExecutor(address(executor));
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

        pool1 = insurancePoolFactory.deployPool(
            "insurance",
            address(ptp),
            1000 ether,
            POOL_ID
        );

        // set addresses for pool1
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setExecutor(address(executor));
        InsurancePool(pool1).setIncidentReport(address(incidentReport));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setOnboardProposal(address(onboardProposal));
        InsurancePool(pool1).setInsurancePoolFactory(
            address(insurancePoolFactory)
        );

        // allow incident report to mint and burn tokens
        // on behalf of users
        deg.addMinter(address(incidentReport));

        // transfer tokens to users

        // report pool
        deg.transfer(address(this), 10000 ether);

        // TODO:
        deg.transfer(address(onboardProposal), 1000 ether);
        deg.approve(address(onboardProposal), 10000 ether);

        // vote on proposals and reports
        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 2000 ether);
        vedeg.transfer(carol, 3000 ether);

        // have shield on main contract
        shield.transfer(address(this), 1000 ether);
        shield.approve(address(policyCenter), 10000 ether);
        // mint and approve tokens for pool1 and pool2
        ptp.approve(address(policyCenter), 10000 ether);
        yeti.approve(address(policyCenter), 10000 ether);

        policyCenter.provideLiquidity(POOL_ID, 10000);
        onboardProposal.proposePool(address(yeti), "Yeti", 10000, 1);
        deg.approve(address(incidentReport), 1000 ether);
        vm.warp(REPORT_START_TIME);
        incidentReport.report(1);
        vm.prank(alice);
        onboardProposal.vote(PROPOSAL_ID, true);
        vm.prank(bob);
        onboardProposal.vote(PROPOSAL_ID, true);
        vm.prank(carol);
        onboardProposal.vote(PROPOSAL_ID, true);
        
        // start voting
        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        // vote on report
        vm.prank(alice);
        incidentReport.vote(POOL_ID, VOTE_FOR, 1000 ether);
        vm.prank(bob);
        incidentReport.vote(POOL_ID, VOTE_FOR, 1000 ether);
        vm.prank(carol);
        incidentReport.vote(POOL_ID, VOTE_FOR, 1000 ether);
        vm.warp( REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);

        incidentReport.settle(POOL_ID);

        //TODO: test onboardProposal
        onboardProposal.evaluatePoolProposalVotes(PROPOSAL_ID);

        // pass yeti pool proposal to executor
        onboardProposal.evaluatePoolProposalVotes(PROPOSAL_ID);
    }

    function testGetPendingPools() public {
        // retrieves pending pool by id
        // should return its state
        (uint256 poolId, , bool pending, bool approved) = executor
            .queuedReportsById(1);
        assertEq(poolId == POOL_ID, true);
        assertEq(pending == true, true);
        assertEq(approved == true, true);
    }

    // function testExecuteReportPriorToBuffer() public {
    //     // report should not be executable prior to time buffer
    //     vm.expectRevert("report not ready");
    //     executor.executeReport(1);
    // }

    function testExecutePoolPriorToBuffer() public {
        // report should not be executable prior to time buffer
        vm.expectRevert("pool not ready");
        executor.executeNewPool(PROPOSAL_ID);
    }

    // function testExecuteReportAfterBuffer() public {
    //     // report should be executable after time buffer
    //     vm.warp(1000000);
    //     executor.executeReport(1);
    //     assertEq(InsurancePool(pool1).liquidated() == true, true);
    // }

    function testExecutePoolAfterBuffer() public {
        // pool should be executable after time buffer
        vm.warp(1000000);
        address newPool = executor.executeNewPool(1);
        address[] memory addresses = insurancePoolFactory.getPoolAddressList();
        address registeredNewPool = addresses[addresses.length - 1];
        assertEq(newPool == registeredNewPool, true);
    }

    // function testExecuteReportNotOwner() public {
    //     // only owner aka manager can execute a report
    //     vm.warp(1000000);
    //     vm.prank(carol);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     executor.executeReport(1);
    // }

    function testExecutePoolNotOwner() public {
        // only owner aka manager can execute a new pool
        vm.warp(1209602);
        vm.prank(carol);
        vm.expectRevert("Ownable: caller is not the owner");
        executor.executeNewPool(1);
    }

    // function testCancelReport() public {
    //     // owner should be able to cancel a report
    //     vm.warp(1000000);
    //     executor.cancelReport(1);
    //     (uint256 poolId, , bool pending, bool approved) = executor
    //         .queuedReportsById(1);
    //     bool truthy = InsurancePool(pool1).liquidated();
    //     assertEq(poolId == 1, true);
    //     assertEq(pending == false, true);
    //     assertEq(approved == true, true);
    //     assertEq(truthy == false, true);
    // }

    function testCancelPool() public {
        // owner should be able to cancel a new pool proposal
        vm.warp(1209602);
        executor.cancelNewPool(1);
        (, , , , , bool pending, ) = executor.queuedPoolsById(1);
        assertEq(pending == false, true);
    }

    // function testCancelReportNotOwner() public {
    //     // users should not be able to cancel a report
    //     vm.warp(1000000);
    //     vm.prank(carol);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     executor.cancelReport(1);
    // }

    function testCancelPoolNotOwner() public {
        // users should not be able to cancel a prposal
        vm.warp(1209602);
        vm.prank(carol);
        vm.expectRevert("Ownable: caller is not the owner");
        executor.cancelNewPool(1);
    }
}
