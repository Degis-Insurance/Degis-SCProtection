// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ProtectionPool.sol";
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
import "src/interfaces/ProtectionPoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IProtectionPool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

contract ClaimPayoutTest is Test, IncidentReportParameters {
    InsurancePoolFactory public insurancePoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    Exchange public exchange;
    Executor public executor;

    ERC20Mock public ptp;
    ERC20Mock public yeti;

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

        // deploy contracts
        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );

        insurancePoolFactory = new InsurancePoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );

        incidentReport = new IncidentReport(
            address(deg),
            address(vedeg),
            address(shield)
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

        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000 ether);
        shield.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);

        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setProtectionPool(address(protectionPool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setExecutor(address(executor));

        protectionPool.setPolicyCenter(address(policyCenter));
        protectionPool.setIncidentReport(address(incidentReport));
        protectionPool.setPolicyCenter(address(policyCenter));

        policyCenter.setExecutor(address(executor));

        policyCenter.setProtectionPool(address(protectionPool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));

        onboardProposal.setExecutor(address(executor));

        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));

        incidentReport.setPolicyCenter(address(policyCenter));
        incidentReport.setProtectionPool(address(protectionPool));
        incidentReport.setInsurancePoolFactory(address(insurancePoolFactory));

        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setIncidentReport(address(incidentReport));
        executor.setProtectionPool(address(protectionPool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));

        pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            260
        );

        InsurancePool(pool1).setExecutor(address(executor));
        InsurancePool(pool1).setIncidentReport(address(incidentReport));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));

        deg.transfer(address(this), 1000 ether);
        deg.transfer(address(onboardProposal), 1000 ether);
        deg.approve(address(onboardProposal), 10000 ether);

        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 2000 ether);
        vedeg.transfer(carol, 3000 ether);

        // Alice will buy coverage
        ptp.transfer(alice, 1000 ether);

        // owner provides liquidity to pool 1
        shield.transfer(address(this), 1000);
        shield.approve(address(policyCenter), 10000 ether);

        policyCenter.provideLiquidity(1, 10000 ether);

        uint256 price = InsurancePool(pool1).coveragePrice(100 ether, 90);

        // Alice approves ptp usage to buy coverage
        ptp.approve(address(policyCenter), 100000 ether);
        ptp.mint(address(policyCenter), 100000 ether);

        vm.prank(alice);
        ptp.approve(address(policyCenter), 100000 ether);

        // Alice buys coverage for 100 ether
        vm.prank(alice);
        policyCenter.buyCover(1, 100 ether, 90);

        vm.warp(REPORT_START_TIME);
        incidentReport.report(1);

        vm.warp(REPORT_START_TIME + PENDING_PERIOD + 1);
        incidentReport.startVoting(POOL_ID);

        vm.prank(alice);
        incidentReport.vote(1, VOTE_FOR, 2500 ether);
        vm.prank(bob);
        incidentReport.vote(1, VOTE_FOR, 2000 ether);
        vm.prank(carol);
        incidentReport.vote(1, VOTE_FOR, 1500 ether);

        vm.warp(REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1);

        incidentReport.settle(POOL_ID);

        // execute pool
        executor.executeReport(1);
    }

    function testClaimPayout() public {
        // claim payout during claiming period
        vm.warp(15 days);
        uint256 amount = policyCenter.calculatePayout(1, address(this));

        vm.prank(alice);
        policyCenter.claimPayout(1);
    }

    function testClaimPayoutUnexsistentPool() public {
        vm.expectRevert("Pool not found");
        policyCenter.claimPayout(2);
    }

    function testUnpauseLiquidatedPool() public {
        vm.warp(1383402);
        InsurancePool(pool1).pauseInsurancePool(false);

        // pool remains liquidated but unpaused
        assertTrue(IInsurancePool(pool1).liquidated());
        assertTrue(!IInsurancePool(pool1).paused());

        uint256 endDate = IInsurancePool(pool1).endLiquidationDate();
        console.log(endDate);

        vm.warp(
            REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1 + 91 days
        );
        IInsurancePool(pool1).endLiquidation();

        assertEq(IInsurancePool(pool1).liquidated() == false, true);
    }

    function testRemoveLiquidityAfterClaimPayoutPeriod() public {
        // claim payout during claiming period
        vm.warp(15 days);
        uint256 amount = policyCenter.calculatePayout(1, address(this));

        vm.prank(alice);
        policyCenter.claimPayout(1);

        uint256 lpBalance = IInsurancePool(pool1).balanceOf(address(this));
        uint256 shieldBalance = shield.balanceOf(address(this));

        vm.warp(
            REPORT_START_TIME + PENDING_PERIOD + VOTING_PERIOD + 1 + 91 days
        );
        incidentReport.unpausePools(address(pool1));

        IInsurancePool(pool1).endLiquidation();
        policyCenter.removeLiquidity(1, lpBalance);

        assertEq(InsurancePool(pool1).liquidated() == false, true);

        // Liquidity provider is able to remove left over liquidity proportional to
        // how much liquidity they provided and how much is left in the pool
        assertEq(
            shieldBalance + (lpBalance - amount) ==
                shield.balanceOf(address(this)),
            true
        );
    }
}
