// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./utils/ContractSetupTest.sol";

import "src/interfaces/IPolicyCenter.sol";

import "src/core/interfaces/PolicyCenterEventError.sol";
import "src/pools/protectionPool/ProtectionPoolEventError.sol";
import "src/pools/priorityPool/PriorityPoolEventError.sol";
import "src/core/interfaces/PolicyCenterDependencies.sol";

contract PolicyCenterTest is
    PolicyCenterEventError,
    ProtectionPoolEventError,
    PriorityPoolEventError,
    ContractSetupBaseTest
{
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    uint256 internal constant JOE_ID = 1;
    uint256 internal constant PTP_ID = 2;
    uint256 internal constant GMX_ID = 3;

    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant PAYOUT = 1000e6;
    uint256 internal constant LIQUIDITY = 1000 ether;

    uint256 internal constant VOTE_FOR = 1;
    uint256 internal constant VOTE_AGAINST = 2;
    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant ZERO_TIME = 0;

    IPriorityPool internal joePool;
    IPriorityPool internal ptpPool;
    IPriorityPool internal gmxPool;

    MockERC20 internal joe;
    MockERC20 internal ptp;
    MockERC20 internal gmx;

    address internal joeLPAddress;
    address internal ptpLPAddress;
    address internal gmxLPAddress;

    address internal crJoeAddress;
    address internal crPtpAddress;
    address internal crGmxAddress;

    function setUp() public {
        setUpContracts();

        // Deploy three protocol tokens
        joe = new MockERC20("JoeToken", "JOE", 18);
        ptp = new MockERC20("PTPToken", "PTP", 18);
        gmx = new MockERC20("GMXToken", "GMX", 18);
        
        // Deploy three priority pools
        joePool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "TraderJoe",
                address(joe),
                CAPACITY_1,
                PREMIUMRATIO_1
            )
        );

        ptpPool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "Platypus",
                address(ptp),
                CAPACITY_2,
                PREMIUMRATIO_2
            )
        );

        gmxPool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "GMX",
                address(gmx),
                CAPACITY_3,
                PREMIUMRATIO_3
            )
        );

        joeLPAddress = joePool.currentLPAddress();
        ptpLPAddress = ptpPool.currentLPAddress();
        gmxLPAddress = gmxPool.currentLPAddress();

    }

    function testProvideLiquidity() public {
        
        // Approve shield expense to Policy Center
        vm.prank(CHARLIE);
        shield.approve(address(policyCenter), LIQUIDITY);
        // # --------------------------------------------------------------------//
        // # Should not be able to provide liquidity without shield # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.provideLiquidity(1);

        console.log(unicode"✅ Not provide liquidity without shield");

        // Mint shield to Charlie
        shield.mint(CHARLIE, LIQUIDITY);

        // # --------------------------------------------------------------------//
        // # Should not be able to provide 0 liquidity # //
        // # --------------------------------------------------------------------//
        
        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__ZeroAmount.selector);
        policyCenter.provideLiquidity(0);

        console.log(unicode"✅ Not provide liquidity offerring zero shield");


        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should not be able to provide liquidity directly to protection pool # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(ProtectionPool__OnlyPolicyCenter.selector);
        protectionPool.providedLiquidity(LIQUIDITY, CHARLIE);

        console.log(unicode"✅ Not provide liquidity directly to protection pool");

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(LIQUIDITY, LIQUIDITY, CHARLIE);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity");

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity in different times # //
        // # --------------------------------------------------------------------//

        vm.revertTo(snapshot_1);

        shield.mint(CHARLIE, LIQUIDITY);
        vm.prank(CHARLIE);
        shield.approve(address(policyCenter), LIQUIDITY * 2);
        vm.warp(365 days);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(LIQUIDITY, LIQUIDITY, CHARLIE);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity after a year");

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity by multiple users # //
        // # --------------------------------------------------------------------//

        shield.mint(ALICE, LIQUIDITY);
        vm.prank(ALICE);
        shield.approve(address(policyCenter), LIQUIDITY);
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(LIQUIDITY, LIQUIDITY, ALICE);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity by multiple users");

    }

    function _provideLiquidity(address _user) private {
        vm.warp(ZERO_TIME);
        shield.mint(_user, LIQUIDITY);
        vm.prank(_user);
        shield.approve(address(policyCenter), LIQUIDITY);
        vm.prank(_user);
        policyCenter.provideLiquidity(LIQUIDITY);
    }

    
    function testStake() public {
        
        vm.prank(ALICE);
        protectionPool.approve(address(policyCenter), LIQUIDITY);
        vm.prank(BOB);
        protectionPool.approve(address(policyCenter), LIQUIDITY);
        vm.prank(CHARLIE);
        protectionPool.approve(address(policyCenter), LIQUIDITY);

        // # --------------------------------------------------------------------//
        // # Should not be able to stake liquidity without providing liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        console.log(unicode"✅ Not stake liquidity without providing liquidity");


        // Provide liquidity by multiple users
        _provideLiquidity(ALICE);
        _provideLiquidity(BOB);
        _provideLiquidity(CHARLIE);

        // staking requires a minimum amount of time passed since priority pool creation
        vm.warp(ZERO_TIME + 1);

        // # --------------------------------------------------------------------//
        // # Should not be able to stake 0 liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__ZeroAmount.selector);
        policyCenter.stakeLiquidity(JOE_ID, 0);

        console.log(unicode"✅ Not stake 0 liquidity");

        // # --------------------------------------------------------------------//
        // # Should not be able to stake more then provided liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        protectionPool.increaseAllowance(address(policyCenter), LIQUIDITY * 2);
        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY * 2);

        console.log(unicode"✅ Not stake more then provided liquidity");

        // # --------------------------------------------------------------------//
        // # Should not be able to stake more then provided liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        console.log(unicode"✅ Not stake more then provided liquidity");
        
    }

    function testUnstake() public {

    }

    function testBuyCover() public {

    }

    function testClaimPayout() public {

    }

    function testRemoveLiquidity() public {

        // # --------------------------------------------------------------------//
        // # Should not be able to remove liquidity without providing liquidity # //
        // # --------------------------------------------------------------------//
        
        vm.prank(CHARLIE);
        vm.expectRevert(ProtectionPool__ExceededTotalSupply.selector);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Not remove liquidity without providing liquidity");
        

        // Charlie provides liquidity
        _provideLiquidity(CHARLIE);

        // # --------------------------------------------------------------------//
        // # Should not be able to remove other user's liquidity # //
        // # --------------------------------------------------------------------//

        // Alice attempts to remove liquidity provided by Charlie 
        vm.prank(ALICE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Not remove other user's liquidity");

        // # --------------------------------------------------------------------//
        // # Should not be able to remove more then liquidity provided without supply # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(ProtectionPool__ExceededTotalSupply.selector);
        policyCenter.removeLiquidity(LIQUIDITY + 1);

        console.log(unicode"✅ Not remove more then liquidity provided");

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(LIQUIDITY, LIQUIDITY, CHARLIE);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Remove liquidity");


        // Provide liquidity by Charlie again
        _provideLiquidity(CHARLIE);
        // Provide extra liquidity by Alice
        _provideLiquidity(ALICE);

        // # --------------------------------------------------------------------//
        // # Should not be able to remove more liquidity then provided with supply # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        policyCenter.removeLiquidity(LIQUIDITY * 2);

        console.log(unicode"✅ Remove liquidity");

        // Provide liquidity by Charlie again
        _provideLiquidity(CHARLIE);

        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity after considrable time # //
        // # --------------------------------------------------------------------//

        vm.warp(365 days);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(LIQUIDITY, LIQUIDITY, CHARLIE);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Remove liquidity after a year");


        vm.revertTo(snapshot_1);

        // Provide liquidity twice by Charlie
        _provideLiquidity(CHARLIE);
        _provideLiquidity(CHARLIE);

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity provided in multiple instances # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(LIQUIDITY * 2, LIQUIDITY * 2, CHARLIE);
        policyCenter.removeLiquidity(LIQUIDITY * 2);

        console.log(unicode"✅ Remove liquidity after a year");

    }

}
