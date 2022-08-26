// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./utils/ContractSetupBaseTest.sol";

import "src/interfaces/IProtectionPool.sol";

import "src/pools/protectionPool/ProtectionPool.sol";

contract ProtectionPoolTest is ContractSetupBaseTest {
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant SCALE = 1e12;

    // Max capacities for pools (100 = 100%)
    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    // Base premium ratio for pools (10000 = 100%)
    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant LIQUIDITY_UNIT = 100e6;

    function setUp() public {
        setUpContracts();

        _preApprove();
    }

    function _preApprove() internal {
        vm.prank(ALICE);
        shield.approve(address(policyCenter), type(uint256).max);

        vm.prank(BOB);
        shield.approve(address(policyCenter), type(uint256).max);

        vm.prank(CHARLIE);
        shield.approve(address(policyCenter), type(uint256).max);
    }

    function testProvideLiquidity() public {
        shield.mint(ALICE, LIQUIDITY_UNIT);

        vm.prank(ALICE);
        policyCenter.provideLiquidity(LIQUIDITY_UNIT);

        assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY_UNIT);
        assertEq(protectionPool.balanceOf(ALICE), LIQUIDITY_UNIT);
    }

    function testRemoveLiquidity() public {
        shield.mint(ALICE, LIQUIDITY_UNIT);

        vm.prank(ALICE);
        policyCenter.provideLiquidity(LIQUIDITY_UNIT);

        vm.prank(ALICE);
        policyCenter.removeLiquidity(LIQUIDITY_UNIT);

        assertEq(shield.balanceOf(address(protectionPool)), 0);
        assertEq(protectionPool.balanceOf(ALICE), 0);
    }
}
