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

import "forge-std/console.sol";

/**
@notice Tests user Interactions from user side.
        Initial
*/
contract PostInsurancePoolDeploymentTest is Test {
    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    // added exchange for mock swapping tokens
    Exchange public exchange;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;

    event Reward(uint256 amount, address token);

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;

    uint256 public constant REINSURANCE_POOL_ID = 0;
    uint256 public constant POOL_ID = 1;
    // 2.6% pool ratio
    uint256 public constant POOL_PRICE_RATIO = 260;
    uint256 constant SCALE = 1e12;

    uint256 public constant VOTING_START_TIME = 3 days;
    uint256 public constant VOTING_END_TIME = 6 days;
    uint256 public constant EXTENSION_TIME = 1 days;
    uint256 public constant CLAIM_PERIOD_TIME = 7 days;

    function setUp() public {
        // deploys tokens
        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");

        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        deg.transfer(address(this), 100 ether);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100 ether);
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

        shield.approve(address(policyCenter), 20000);

        // Deploy exchange and supply tokens so they
        // can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000 ether);
        shield.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);

        // Fund alice's account
        deg.transfer(alice, 1000 ether);
        ptp.transfer(alice, 1000 ether);
        shield.transfer(alice, 1000 ether);
        vedeg.transfer(alice, 1000 ether);

        // fund owner with shield
        shield.transfer(address(this), 1000 ether);

        // sets addresses needed to execute functions

        insurancePoolFactory.setPolicyCenter(address(policyCenter));

        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));

        policyCenter.setExecutor(address(executor));

        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));

        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setIncidentReport(address(incidentReport));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        onboardProposal.setExecutor(address(executor));

        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));

        incidentReport.setPolicyCenter(address(policyCenter));
        incidentReport.setReinsurancePool(address(reinsurancePool));
        incidentReport.setInsurancePoolFactory(address(insurancePoolFactory));

        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        // deploy ptp pool
        pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            POOL_PRICE_RATIO
        );
        // set addreses for ptp pool

        InsurancePool(pool1).setPolicyCenter(address(policyCenter));

        InsurancePool(pool1).setIncidentReport(address(incidentReport));
    }

    function testGetPoolAddressList() public {
        // reads list of pools in the protocol
        address[] memory list = insurancePoolFactory.getPoolAddressList();
        uint256 length = list.length;
        for (uint256 i = 0; length > i; i++) {
            console.log(list[i]);
        }
        // asserts that the list is not empty
        assertEq(list[0] == address(reinsurancePool), true);
        assertEq(list[1] == pool1, true);
    }

    // test approve transfer of tokens to policy center
    // it will handle all transfers from protocol to users and vice versa
    function testApproveDegPolicyCenter() public {
        deg.approve(address(policyCenter), 10000 ether);
        assertEq(
            deg.allowance(address(this), address(policyCenter)) == 10000 ether,
            true
        );
    }


    function testApprovePTPPolicyCenter() public {
        // approve ptp pool to policy center
        ptp.approve(address(policyCenter), 10000 ether);
        assertEq(
            ptp.allowance(address(this), address(policyCenter)) == 10000 ether,
            true
        );
    }

    function testProvideLiquidityInsurancePool() public {
        // user should be able to provide liquidity to ptp pool in ptp
        shield.approve(address(policyCenter), 10000 ether);

        policyCenter.provideLiquidity(POOL_ID, 10000);

        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityBeforeBufferTimeEndInsnsurancePool() public {
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(POOL_ID, 10000);
        vm.expectRevert("cannot remove liquidity within 7 days of last claim");
        policyCenter.removeLiquidity(POOL_ID, 10000);
        // user should not be able to remove liquidity and liquidities should remain the same.
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityAfterBufferTimeEndsInsurancePool() public {
        // provide liquidity
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(POOL_ID, 10000);

        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        // change block timestamp to after buffer time
        vm.warp(7 days + 1);

        console.log(InsurancePool(pool1).totalSupply());
        policyCenter.removeLiquidity(POOL_ID, 10000);
    }

    function testExceedMaxCapacity() public {
        shield.approve(address(policyCenter), 10000 ether);
        ptp.approve(address(policyCenter), 10000 ether);

        uint256 price = InsurancePool(pool1).coveragePrice(10000 ether, 90);

        // test should revert and emit message
        vm.expectRevert("exceeds max capacity");
        policyCenter.buyCover(POOL_ID, 10000 ether, 90);
    }

    function testProvideLiqudityDirectlyToInsurancePool() public {
        shield.approve(address(policyCenter), 10000 ether);
        // user should not be able to provide liquidity directly to insurance pool
        vm.expectRevert("Only policy center can call this function");
        InsurancePool(pool1).provideLiquidity(10000, address(this));
    }

    function testRemoveLiquidityDirectlyFromInsurancePool() public {
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(POOL_ID, 10000);
        vm.warp(604801);
        // user should not be able to provide liquidity directly to insurance pool
        vm.expectRevert("Only policy center can call this function");
        InsurancePool(pool1).removeLiquidity(10000, address(this));
    }

    function testRemoveLiquidityWithoutProvidingLiquidity() public {
        // user should not be able to remove liquidity without providing liquidity
        vm.expectRevert("Amount must be less than provided liquidity");
        policyCenter.removeLiquidity(POOL_ID, 1);
    }

    function testGetCoverPrice() public {
        uint256 amount = 100 ether;
        uint256 length = 90;
        // get coverage price and returns it
        uint256 price = InsurancePool(pool1).coveragePrice(amount, length);
        uint256 expectedPrice = (length * POOL_PRICE_RATIO * amount) / 3650000;

        assertEq(price == expectedPrice, true);
    }

    function testBuyCoverWithoutSuppliedLiquidity() public {
        // expected behavior when coverage is bough with
        // liquidity provided by other users

        shield.transfer(alice, 1000 ether);
        deg.transfer(alice, 1000 ether);
        vedeg.transfer(alice, 1000 ether);

        // Approve policy center to transfer tokens
        // for user alice.
        vm.prank(alice);
        shield.approve(address(policyCenter), 10000 ether);
        vm.prank(alice);
        deg.approve(address(policyCenter), 10000 ether);
        vm.prank(alice);
        vedeg.approve(address(policyCenter), 10000 ether);

        // get price
        uint256 price = InsurancePool(pool1).coveragePrice(1000 ether, 90);

        //; approve ptp to buy coverage
        vm.prank(alice);
        ptp.approve(address(policyCenter), 10000 ether);
        // user buys coverage with liquidity after liquidity has been provided
        vm.prank(alice);
        policyCenter.buyCover(POOL_ID, 1000 ether, 90);

        (uint256 amount, uint256 buyDate, uint256 length) = policyCenter.covers(
            POOL_ID,
            alice
        );

        assertEq(amount, 1000 ether);
        assertEq(buyDate - block.timestamp < 604810, true);
        assertEq(length == 90, true);
    }

    function testBuyCoverWithSuppliedLiquidity() public {
        // expected behavior when coverage is bough with
        // liquidity provided by other users

        shield.transfer(alice, 1000 ether);
        deg.transfer(alice, 1000 ether);
        vedeg.transfer(alice, 1000 ether);

        // Approve policy center to transfer tokens
        // for user alice.
        vm.prank(alice);
        shield.approve(address(policyCenter), 10000 ether);
        vm.prank(alice);
        deg.approve(address(policyCenter), 10000 ether);
        vm.prank(alice);
        vedeg.approve(address(policyCenter), 10000 ether);

        // Owner address provides liquidity to ptp pool
       
        vm.prank(alice);
        policyCenter.provideLiquidity(POOL_ID, 1000);
        uint256 price = InsurancePool(pool1).coveragePrice(100 ether, 90);

        //; approve ptp to buy coverage
        vm.prank(alice);
        ptp.approve(address(policyCenter), 10000 ether);
        // user buys coverage with liquidity after liquidity has been provided
        vm.prank(alice);
        policyCenter.buyCover(POOL_ID, 100 ether, 90);
        (uint256 amount, uint256 buyDate, uint256 length) = policyCenter.covers(
            POOL_ID,
            alice
        );
        assertEq(amount == 100 ether, true);
        assertEq(buyDate - block.timestamp < 604810, true);
        assertEq(length == 90, true);
    }

    function testProvideLiquidityReinsurancePool() public {
        // user should be able to provide liquidity to reinsurance pool
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(REINSURANCE_POOL_ID, 10000);
        assertEq(
            ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000,
            true
        );
    }

    function testRemoveLiquidityBeforeBufferTimeReinsurancePool() public {
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(REINSURANCE_POOL_ID, 10000);
        // user should not be able to remove liquidity from reinsurance pool prior to buffer time
        vm.expectRevert("cannot remove liquidity within 7 days of last claim");
        policyCenter.removeLiquidity(REINSURANCE_POOL_ID, 10000);
        assertEq(
            ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000,
            true
        );
        assertEq(
            ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000,
            true
        );
    }

    function testRemoveLiquidityAfterBufferTimeReinsurancePool() public {
        // user should be able to remove liquidity from reinsurance pool after buffer time
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.provideLiquidity(REINSURANCE_POOL_ID, 10000);
        uint256 initialBalance = ptp.balanceOf(address(this));
        assertEq(
            ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000,
            true
        );
        vm.warp(604801);
        policyCenter.removeLiquidity(REINSURANCE_POOL_ID, 10000);
        assertEq(ptp.balanceOf(address(this)) == initialBalance, true);
    }

    function testSetPremiumSplit() public {
        // owner should be able to change premium split, up to 1000 bps
        policyCenter.setPremiumSplit(2000, 7000);
        (uint256 split1, uint256 split2) = policyCenter.getPremiumSplits();
        assertEq(split1 == 2000, true);
        assertEq(split2 == 7000, true);
    }

    function testSetPremiumSplitBadInput() public {
        vm.expectRevert("Invalid split");
        // sum > 100%
        policyCenter.setPremiumSplit(3001, 7000);
    }

    function testFundsAreSplit() public {
        // test if funds end up being split properly among treasury, insurance pool and reinsurance pool
        vm.prank(alice);
        ptp.approve(address(policyCenter), 10000 ether);

        uint256 prevBalance = ptp.balanceOf(address(policyCenter));

        uint256 price = InsurancePool(pool1).coveragePrice(1000 ether, 90);

        vm.prank(alice);
        policyCenter.buyCover(POOL_ID, 1000 ether, 90);

        console.log(ptp.balanceOf(address(policyCenter)));

        uint256 expectedBalance = prevBalance + ((price * 45) / 100);
        console.log(expectedBalance);
        // assert that funds are split correctly, ptp balance is 45% of price and consider trade ratio
        assertEq(ptp.balanceOf(address(policyCenter)) == expectedBalance, true);
    }

    function testRemoveLiquidityAfterReport() public {
        // user should not be able to remove liquidity if pool has been reported
        shield.approve(address(policyCenter), 10000 ether);
        ptp.approve(address(policyCenter), 10000 ether);
        deg.approve(address(policyCenter), 10000 ether);
        deg.approve(address(incidentReport), 10000 ether);

        policyCenter.provideLiquidity(POOL_ID, 10000);

        vm.warp(7 days + 1);

        incidentReport.report(1);

        vm.expectRevert("Pausable: paused");
        policyCenter.removeLiquidity(POOL_ID, 10000);
    }

    function testClaimRewardsFromLiquidityProvisionNoRewards() public {
        // claim rewards for liquidity provision in a non liquidated pool
        // no coverage bought, therefore no rewards are available

        vm.prank(alice);
        ptp.approve(address(policyCenter), 1000 ether);
        vm.prank(alice);
        shield.approve(address(policyCenter), 1000 ether);
        vm.prank(alice);
        policyCenter.provideLiquidity(POOL_ID, 1000);
        vm.warp(30 days);
        vm.prank(alice);

        // claiming on the same block as provisioning should not give any rewards
        uint256 reward = policyCenter.calculateReward(POOL_ID, alice);

        assertEq(reward == 0, true);
        // no user should be able to claim rewards

        vm.prank(alice);
        policyCenter.claimReward(POOL_ID);
    }

    function testClaimRewardsFromLiquidityProvisionOneDayReward() public {
        // claim rewards for liquidity provision in a non liquidated pool
        // no coverage bought, therefore no rewards are available

        vm.prank(alice);
        ptp.approve(address(policyCenter), 1000 ether);
        vm.prank(alice);
        shield.approve(address(policyCenter), 1000 ether);
        vm.prank(alice);
        policyCenter.provideLiquidity(POOL_ID, 1000);
        vm.warp(30 days);
        vm.prank(alice);

        vm.warp(31 days);
        // claiming on the same block as provisioning should not give any rewards
        uint256 reward = policyCenter.calculateReward(POOL_ID, alice);

        console.log("reward", reward);
        // no user should be able to claim rewards
        vm.prank(alice);
        policyCenter.claimReward(POOL_ID);
    }
}
