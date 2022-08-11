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

import "src/pools/InsurancePool.sol";
import "src/pools/ProtectionPool.sol";
import "src/pools/InsurancePoolFactory.sol";

import "src/core/PolicyCenter.sol";

contract InsurancePoolTest is BaseTest {
    address alice = mkaddr("alice");
    address bob = mkaddr("bob");

    ProtectionPool protectionPool;
    InsurancePoolFactory factory;
    InsurancePool pool;

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

        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");
        vedeg = new MockVeDEG(1000 ether, "veDegis", 18, "veDeg");

        exchange = new Exchange();

        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );

        factory = new InsurancePoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );

        policyCenter = new PolicyCenter(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );

        factory.setPolicyCenter(address(policyCenter));
        policyCenter.setInsurancePoolFactory(address(factory));
        policyCenter.setExchange(address(exchange));

        // pools require initial liquidity input to Protection pool
        policyCenter.provideLiquidity(10000 ether);
    }

    function testFactorySetUp() public {
        InsurancePoolFactory.PoolInfo memory firstPool = factory.getPoolInfo(0);

        assertEq(firstPool.protocolName, "ProtectionPool");
        assertEq(firstPool.protocolToken, address(shield));

        assertTrue(factory.tokenRegistered(address(shield)));
        assertTrue(factory.poolRegistered(address(protectionPool)));
    }

    function testDeployPool() public {
        address newPoolAddress = factory.deployPool(
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

        pool = InsurancePool(newPoolAddress);

        uint256 price = pool.coverPrice(10 ether, 90);
        console.log("price", price);
    }
}
