// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../src/util/FlashLoanPool.sol";
import "./utils/BaseTest.sol";
import "./utils/ContractSetupBaseTest.sol";
import "../src/voting/incidentReport/IncidentReportParameters.sol";

contract FlashLoanTest is
    Test,
    FlashLoanPool,
    ContractSetupBaseTest,
    IncidentReportParameters
{
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

    uint256 internal constant LIQUIDITY = 1000 ether;

    // uint256 internal constant VOTE_FOR = 1;
    // uint256 internal constant VOTE_AGAINST = 2;
    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant INCIDENT_VOTE_TIME = PENDING_PERIOD;

    uint256 internal constant INCIDENT_SETTLE_TIME =
        INCIDENT_VOTE_TIME + INCIDENT_VOTING_PERIOD;

    IPriorityPool internal joePool;

    MockERC20 internal joe;
    MockERC20 internal shield;

    address internal joeLPAddress;

    address internal crJoeAddress;

    // effectively a "beforeEach" block
    function setUp() public {
        _setupContracts();
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(this), "TestContract");

        shield = new MockERC20("shield", "SHD", 18);
        vm.label(address(shield), "SHIELD");

        shield.mint(address(this), 1e18);
        shield.approve(address(protectionPool), LIQUIDITY);
    }

    function testConstructNonZeroToken() public {
        vm.expectRevert(flashLoanPool.TokenAddressCannotBeZero.selector);
        new FlashLoanPool(address(0x0));
    }

    function testPoolBalance() public {
        shield.approve(address(protectionPool), LIQUIDITY);
        protectionPool.deposit(LIQUIDITY);
        uint256 maxFlashLoan = flashLoanPool.maxFlashLoan(address(shield));
        uint256 fee = flashLoanPool.flashFee(address(shield), maxFlashLoan);
        assertEq(shield.balanceOf(protectionPool), LIQUIDITY + fee);
    }

    function testBorrowZeroRevert() public {
        vm.expectRevert(FlashLoanPool__MinnimumNotMet.selector);
        flashLoanPool.flashLoan(msg.sender, address(shield), 0, "");
    }

    function testBorrowMoreRevert() public {
        vm.expectRevert(FlashLoanPool__NotEnoughFunds.selector);
        flashLoanPool.flashLoan(msg.sender, address(shield), LIQUIDITY * 2, "");
    }

    function testReturnAmountRevert() public {
        vm.expectRevert(FlashLoanPool__NotPaidBack.selector);
        flashLoanPool.flashLoan(msg.sender, address(shield), LIQUIDITY, "");
    }

    function testFlashLoan() public {
        // we want to borrow and return right away
        return_amount = LIQUIDITY;
        flashLoanPool.flashLoan(msg.sender, address(shield), LIQUIDITY, "");
        assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY);
    }

    function testOnlyOwnerRevert() public {
        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        flashLoanPool.setProtectionPool(bob);
        vm.stopPrank();
    }

    function testFuzzFlashLoan(uint256 borrow_amount, uint256 _return_amount)
        public
    {
        vm.assume(borrow_amount > 0);
        vm.assume(_return_amount <= shield.balanceOf(address(this)));
        vm.assume(borrow_amount <= _return_amount);
        vm.assume(borrow_amount <= shield.balanceOf(address(flashLoanPool)));

        vm.expectEmit(true, true, false, true);
        emit FlashLoanBorrowed(
            address(protectionPool),
            address(this),
            address(shield),
            fee
        );
        flashLoanPool.flashLoan(msg.sender, address(shield), LIQUIDITY, "");
        assertEq(
            shield.balanceOf(address(flashLoanPool)),
            shield.balanceOf(address(protectionPool))
        );
    }
}
