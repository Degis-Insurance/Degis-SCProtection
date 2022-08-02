// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockExchange.sol";

import "src/pools/InsurancePool.sol";
import "src/pools/ReinsurancePool.sol";
import "src/pools/InsurancePoolFactory.sol";

import "src/core/PolicyCenter.sol";

contract InsurancePoolTest is BaseTest {
    address alice = mkaddr("alice");
    address bob = mkaddr("bob");

    ReinsurancePool repool;
    InsurancePoolFactory factory;
    InsurancePool pool;

    PolicyCenter public policyCenter;

    MockDEG deg;

    Exchange exchange;

    ERC20Mock joe;
    ERC20Mock gmx;

    function setUp() public {
        deg = new MockDEG(0, "DegisToken", 18, "DEG");
        gmx = new ERC20Mock("GMX", "GMX", address(this), 0);
        exchange = new Exchange();

        repool = new ReinsurancePool();
        factory = new InsurancePoolFactory(address(repool), address(deg));

        policyCenter = new PolicyCenter(address(repool), address(deg));

        factory.setPolicyCenter(address(policyCenter));
        policyCenter.setInsurancePoolFactory(address(factory));
        policyCenter.setExchange(address(exchange));
    }

    function testFactorySetUp() public {
        InsurancePoolFactory.PoolInfo memory firstPool = factory.getPoolInfo(0);

        assertEq(firstPool.protocolName, "ReinsurancePool");
        assertEq(firstPool.protocolToken, address(deg));

        assertTrue(factory.tokenRegistered(address(deg)));
        assertTrue(factory.poolRegistered(address(repool)));
    }

    function testDeployPool() public {
        address newPoolAddress = factory.deployPool(
            "gmx pool",
            address(gmx),
            1000 ether,
            1
        );

        uint256 allowance = gmx.allowance(
            address(policyCenter),
            address(exchange)
        );
        assertEq(allowance, type(uint256).max);
    }
}
