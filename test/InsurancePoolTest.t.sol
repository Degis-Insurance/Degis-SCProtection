// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockExchange.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockVeDEG.sol";

import "src/pools/priorityPool/PriorityPool.sol";
import "src/pools/protectionPool/ProtectionPool.sol";
import "src/pools/PremiumRewardPool.sol";
import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/reward/WeightedFarmingPool.sol";
import "src/pools/PayoutPool.sol";
import "src/reward/WeightedFarmingPool.sol";

import "src/core/PolicyCenter.sol";

contract PriorityPoolTest is BaseTest {
    address alice = mkaddr("alice");
    address bob = mkaddr("bob");

    ProtectionPool public protectionPool;
    PriorityPoolFactory public priorityPoolFactory;
    PremiumRewardPool public premiumRewardPool;
    WeightedFarmingPool public weightedFarmingPool;
    PriorityPool public pool;
    PayoutPool public payoutPool;

    PolicyCenter public policyCenter;

    MockDEG deg;
    MockVeDEG vedeg;
    MockSHIELD shield;

    Exchange exchange;

    ERC20Mock joe;
    ERC20Mock gmx;

    function setUp() public {
        deg = new MockDEG(0, "DegisToken", 18, "DEG");
        gmx = new ERC20Mock("GMX", "GMX", address(this), 0);

        shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
        vedeg = new MockVeDEG(1000 ether, "veDegis", 18, "veDeg");

        exchange = new Exchange();

        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );

        priorityPoolFactory = new PriorityPoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );

        premiumRewardPool = new PremiumRewardPool(
            address(shield),
            address(priorityPoolFactory),
            address(protectionPool)
        );
        priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));

        policyCenter = new PolicyCenter(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );

        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        weightedFarmingPool = new WeightedFarmingPool(
            address(premiumRewardPool)
        );
        weightedFarmingPool.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setWeightedFarmingPool(address(weightedFarmingPool));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExchange(address(exchange));
        protectionPool.setPolicyCenter(address(policyCenter));

        shield.transfer(address(this), 10000 ether);
        shield.approve(address(policyCenter), 10000 ether);
        // pools require initial liquidity input to Protection pool
        policyCenter.provideLiquidity(10000 ether);
    }

    function testFactorySetUp() public {
        PriorityPoolFactory.PoolInfo memory firstPool = priorityPoolFactory.getPoolInfo(0);

        assertEq(firstPool.protocolName, "ProtectionPool");
        assertEq(firstPool.protocolToken, address(shield));

        assertTrue(priorityPoolFactory.tokenRegistered(address(shield)));
        assertTrue(priorityPoolFactory.poolRegistered(address(protectionPool)));
    }

    function testDeployPool() public {
        address newPoolAddress = priorityPoolFactory.deployPool(
            "gmx pool",
            address(gmx),
            1000 ether,
            100
        );

        uint256 allowance = gmx.allowance(
            address(policyCenter),
            address(exchange)
        );
        assertEq(allowance, type(uint256).max);

        pool = PriorityPool(newPoolAddress);

        (uint256 price, uint256 length) = pool.coverPrice(10 ether, 3);
        console.log("price", price);
    }
}
