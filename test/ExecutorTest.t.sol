// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/pools/protectionPool/ProtectionPool.sol";
import "src/pools/PremiumRewardPool.sol";
import "src/pools/PayoutPool.sol";
import "src/pools/PremiumRewardPool.sol";

import "src/core/PolicyCenter.sol";
import "src/voting/onboardProposal/OnboardProposal.sol";
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

contract ExecutorTest is Test, IncidentReportParameters {
    PriorityPoolFactory public priorityPoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    PremiumRewardPool public premiumRewardPool;
    OnboardProposal public onboardProposal;
    PayoutPool public payoutPool;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    PriorityPool public insurancePool;
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
        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);
        
        payoutPool = new PayoutPool();
        // Reinsurance pool init
        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );

        // Insurance pool factory init
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

        // deploy exchange and supply tokens so that they
        // can be swapped when coverage is bought and split among pools
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000 ether);
        shield.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);

        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setExecutor(address(executor));
        priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));

        protectionPool.setIncidentReport(address(incidentReport));
        protectionPool.setPolicyCenter(address(policyCenter));
        protectionPool.setPolicyCenter(address(policyCenter));

        policyCenter.setExecutor(address(executor));
        policyCenter.setProtectionPool(address(protectionPool));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExchange(address(exchange));

        // onboardProposal.setExecutor(address(executor));
        onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));

        incidentReport.setPriorityPoolFactory(address(priorityPoolFactory));

        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setIncidentReport(address(incidentReport));
        executor.setProtectionPool(address(protectionPool));
        executor.setPriorityPoolFactory(address(priorityPoolFactory));

        // pools require initial liquidity input to Protection pool
        // policyCenter.provideLiquidity(10000 ether);

        pool1 = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            100
        );

        // set addresses for pool1

        PriorityPool(pool1).setExecutor(address(executor));
        PriorityPool(pool1).setIncidentReport(address(incidentReport));
        PriorityPool(pool1).setPolicyCenter(address(policyCenter));

        // report pool
        deg.transfer(address(this), 10000 ether);

        deg.transfer(address(onboardProposal), 1000 ether);
        deg.approve(address(onboardProposal), 10000 ether);

        // vote on proposals and reports
        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 3000 ether);
        vedeg.transfer(carol, 3000 ether);

        // have shield on main contract
        shield.transfer(address(this), 1000 ether);
        shield.approve(address(policyCenter), 10000 ether);
        // mint and approve tokens for pool1 and pool2
        ptp.approve(address(policyCenter), 10000 ether);
        yeti.approve(address(policyCenter), 10000 ether);

        // first provide liquidity to protection pool
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(10000);
        // get current lp address to approve expence
        protectionPool.approve(address(policyCenter), 10000 ether);
        policyCenter.stakeLiquidity(POOL_ID, 10000);

        // approve deg usage to report and propose pools
        deg.approve(address(incidentReport), 100000 ether);

        vm.warp(REPORT_START_TIME);

        // propose pool
        onboardProposal.propose("Yeti", address(yeti), 100, 1);

        // report pool
        incidentReport.report(1);

        // start voting
        vm.warp(REPORT_START_TIME + VOTING_PERIOD + 1);
        onboardProposal.startVoting(PROPOSAL_ID);
        incidentReport.startVoting(POOL_ID);

        // Vote on proposals
        vm.prank(alice);
        onboardProposal.vote(PROPOSAL_ID, VOTE_FOR, 1500 ether);
        vm.prank(bob);
        onboardProposal.vote(PROPOSAL_ID, VOTE_FOR, 1500 ether);
        vm.prank(carol);
        onboardProposal.vote(PROPOSAL_ID, VOTE_FOR, 2000 ether);

        // vote on report
        vm.prank(alice);
        incidentReport.vote(POOL_ID, VOTE_FOR, 1500 ether);
        vm.prank(bob);
        incidentReport.vote(POOL_ID, VOTE_FOR, 1500 ether);
        vm.prank(carol);
        incidentReport.vote(POOL_ID, VOTE_FOR, 1000 ether);

        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);

        incidentReport.settle(POOL_ID);

        onboardProposal.settle(PROPOSAL_ID);
    }

    function testExecuteProposal() public {
        vm.warp(8 days);
        // execute proposal
        pool2 = executor.executeProposal(PROPOSAL_ID);
        // expect that pool2 is deployed
        address insuredToken = IPriorityPool(pool2).insuredToken();
        assertEq(insuredToken, address(yeti));
    }

    function testExecuteReport() public {
        vm.warp(8 days);
        // execute report
        executor.executeReport(POOL_ID);

        // expect that pool1 is now in the liquidation state
        assertEq(PriorityPool(pool1).liquidated() == true, true);
    }
}
