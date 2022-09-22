// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {ProtectionPool} from "../src/pools/protectionPool/ProtectionPool.sol";
import "src/util/FlashLoanPool.sol";
import "utils/ContractSetupBaseTest.sol";
import "src/mock/MockERC20.sol";
import "./utils/Receiver.sol";
import "./utils/BadReceiver.sol";

contract FlashLoanTest is Test, FlashLoanPool, ContractSetupBaseTest {
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant CAPACITY_1 = 40;

    uint256 internal constant JOE_ID = 1;

    uint256 internal constant PREMIUMRATIO_1 = 200;

    uint256 internal constant COVER_AMOUNT = 1e18;
    uint256 internal constant PAYOUT = 1e18;
    uint256 internal constant LIQUIDITY_UNIT = 100e6;
    uint256 internal constant MIN_COVER_AMOUNT = 100e6;
    uint256 internal constant SCALE = 1e12;
    uint256 internal returnAmount;

    uint256 internal constant LIQUIDITY = 1000 ether;

    IPriorityPool internal joePool;

    MockERC20 internal vedeg;

    Receiver internal receiver;

    bytes internal data = "";

    address internal alice = mkaddr("Alice");
    address internal bob = mkaddr("Bob");

    // effectively a "beforeEach" block
    function setUp() public {
        setUpContracts();
        deg = new MockDEG(0, "Degis", 18, "DEG");
        vedeg = new MockERC20("VoteEscrowedDegis", "veDEG", 18);
        receiver = new Receiver(IERC3156FlashLender(protectionPool));
        shield.mint(address(alice), LIQUIDITY);
        vm.prank(alice);
        shield.approve(address(policyCenter), type(uint256).max);

        shield.approve(address(protectionPool), type(uint256).max);
    }

    function testConstructNonZeroToken() public {
        ProtectionPool ptemp = new ProtectionPool();
        vm.expectRevert(FlashLoanPool__TokenAddressNotZero.selector);
        ptemp.initialize(address(deg), address(vedeg), address(0x0));
    }

    function testPoolBalance() public {
        vm.prank(alice);
        policyCenter.provideLiquidity(LIQUIDITY);
        uint256 maxFlashLoan = protectionPool.maxFlashLoan(address(shield));
        uint256 fee = protectionPool.flashFee(address(shield), maxFlashLoan);
        assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY);
        assertEq(maxFlashLoan, LIQUIDITY);
        assertEq(fee, (LIQUIDITY / 10000) * 10);
    }

    function testBorrowZeroRevert() public {
        shield.mint(address(receiver), LIQUIDITY / 100);
        vm.prank(address(receiver));
        shield.approve(address(protectionPool), type(uint256).max);
        testPoolBalance();
        vm.expectRevert(FlashLoanPool__MinnimumNotMet.selector);
        protectionPool.flashLoan(receiver, address(shield), 0, data);
    }

    function testBorrowMoreRevert() public {
        testPoolBalance();
        shield.mint(address(receiver), LIQUIDITY / 100);
        vm.prank(address(receiver));
        shield.approve(address(protectionPool), type(uint256).max);
        vm.expectRevert(FlashLoanPool__NotEnoughFunds.selector);
        protectionPool.flashLoan(
            receiver,
            address(shield),
            LIQUIDITY * 2,
            data
        );
    }

    function testReturnAmountRevert() public {
        BadReceiver badReceiver = new BadReceiver(IERC3156FlashLender(protectionPool));
        shield.mint(address(badReceiver), LIQUIDITY);
        testPoolBalance();
        vm.prank(address(badReceiver));
        shield.approve(address(protectionPool), type(uint256).max);
        vm.expectRevert(FlashLoanPool__NotPaidBack.selector);
        protectionPool.flashLoan(badReceiver, address(shield), LIQUIDITY, data);
    }

    function testFlashLoan() public {
        testPoolBalance();
        // we want to borrow and return right away
        shield.mint(address(receiver), LIQUIDITY / 100);
        vm.prank(address(receiver));
        shield.approve(address(protectionPool), type(uint256).max);
        uint256 fee = protectionPool.flashFee(address(shield), LIQUIDITY);
        protectionPool.flashLoan(receiver, address(shield), LIQUIDITY, data);
        assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY + fee);
    }

    function testFuzzFlashLoan(uint256 _borrowAmount, uint256 _returnAmount)
        public
    {
        testPoolBalance();
        vm.assume(_borrowAmount > 0);
        vm.assume(_returnAmount <= shield.balanceOf(address(this)));
        vm.assume(_borrowAmount <= _returnAmount);
        vm.assume(_borrowAmount <= shield.balanceOf(address(protectionPool)));
        uint256 fee = protectionPool.flashFee(address(shield), _borrowAmount);
        shield.mint(address(receiver), LIQUIDITY / 100);
        vm.prank(address(receiver));
        shield.approve(address(protectionPool), type(uint256).max);

        vm.expectEmit(true, true, false, true);
        emit FlashLoanBorrowed(
            address(this),
            address(protectionPool),
            address(shield),
            _borrowAmount,
            fee
        );
        protectionPool.flashLoan(receiver, address(shield), LIQUIDITY, data);
        assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY + fee);
    }
}
