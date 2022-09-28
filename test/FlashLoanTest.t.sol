// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.15;

// import "ds-test/test.sol";
// import "forge-std/Vm.sol";
// import "forge-std/console.sol";
// import {ProtectionPool} from "../src/pools/protectionPool/ProtectionPool.sol";
// import "src/util/FlashLoanPool.sol";
// import "utils/ContractSetupBaseTest.sol";
// import "src/mock/MockERC20.sol";
// import "./utils/Receiver.sol";
// import "./utils/BadReceiver.sol";
// import "./utils/ArbitrageReceiver.sol";
// import "src/mock/MockArbitrageExchange.sol";

// contract FlashLoanTest is Test, FlashLoanPool, ContractSetupBaseTest {
//     address internal ALICE = mkaddr("Alice");
//     address internal BOB = mkaddr("Bob");
//     address internal CHARLIE = mkaddr("Charlie");

//     uint256 internal constant LIQUIDITY = 1000 ether;
    
//     MockArbitrageExchange internal arbitrageExchange;

//     IPriorityPool internal joePool;

//     MockERC20 internal vedeg;

//     // Deploy multiple arbitrage strategies
//     Receiver internal receiver;
//     ArbitrageReceiver internal arbitrageReceiver;
//     BadReceiver internal badReceiver;

//     bytes internal data = "";

//     address internal alice = mkaddr("Alice");
//     address internal bob = mkaddr("Bob");

//     function setUp() public {
//         // Setup Contracts
//         setUpContracts();

//         // Setup arbitrage exchange
//         arbitrageExchange = new MockArbitrageExchange();

//         // Setup required vedeg
//         vedeg = new MockERC20("VoteEscrowedDegis", "veDEG", 18);

//         // fund exchange
//         MockERC20(policyCenter.usdc()).mint(
//             address(arbitrageExchange),
//             LIQUIDITY * 10
//         );
//         shield.mint(address(arbitrageExchange), LIQUIDITY * 10);
//         receiver = new Receiver(IERC3156FlashLender(protectionPool));
//         arbitrageReceiver = new ArbitrageReceiver(
//             IERC3156FlashLender(protectionPool),
//             MockArbitrageExchange(arbitrageExchange),
//             ERC20(address(shield))
//         );
//         badReceiver = new BadReceiver(
//             IERC3156FlashLender(protectionPool),
//             MockArbitrageExchange(arbitrageExchange),
//             ERC20(address(shield))
//         );


//         // Alice provides liquidity to protection pool
//         shield.mint(address(alice), LIQUIDITY);
//         vm.prank(alice);
//         shield.approve(address(policyCenter), type(uint256).max);
//     }

//     function testInitializerNonZeroToken() public {
//         // # --------------------------------------------------------------------//
//         // # Initializer should only accept non-zero token addressses # //
//         // # --------------------------------------------------------------------//

//         ProtectionPool ptemp = new ProtectionPool();
//         vm.expectRevert(FlashLoanPool__TokenAddressNotZero.selector);
//         ptemp.initialize(address(deg), address(vedeg), address(0x0));

//         console.log(unicode"✅ Only accept non-zero token address");

//     }

//     function testPoolBalance() public {
//         vm.prank(alice);

//         // # --------------------------------------------------------------------//
//         // # Pool should have a balance # //
//         // # --------------------------------------------------------------------//

//         policyCenter.provideLiquidity(LIQUIDITY);
//         uint256 maxFlashLoan = protectionPool.maxFlashLoan(address(shield));
//         uint256 fee = protectionPool.flashFee(address(shield), maxFlashLoan);
//         assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY);
//         assertEq(maxFlashLoan, LIQUIDITY);
//         assertEq(fee, (LIQUIDITY / 10000) * 10);

//         console.log(unicode"✅ Pool has balance");

//     }

//     function testBorrowZeroRevert() public {

//         // # --------------------------------------------------------------------//
//         // # Should not be able to borrow more than pool balance # //
//         // # --------------------------------------------------------------------//

//         shield.mint(address(receiver), LIQUIDITY / 1000);
//         vm.prank(address(receiver));
//         shield.approve(address(protectionPool), type(uint256).max);
//         testPoolBalance();
//         vm.expectRevert(FlashLoanPool__MinnimumNotMet.selector);
//         protectionPool.flashLoan(receiver, address(shield), 0, data);

//         console.log(unicode"✅ Not borrow 0");
//     }

//     function testBorrowMoreRevert() public {
//         testPoolBalance();

//         // # --------------------------------------------------------------------//
//         // # Should not be able to borrow more than pool balance # //
//         // # --------------------------------------------------------------------//

//         shield.mint(address(receiver), LIQUIDITY / 1000);
//         vm.prank(address(receiver));
//         shield.approve(address(protectionPool), type(uint256).max);
//         vm.expectRevert(FlashLoanPool__NotEnoughFunds.selector);
//         protectionPool.flashLoan(
//             receiver,
//             address(shield),
//             LIQUIDITY * 2,
//             data
//         );

//         console.log(unicode"✅ Not borrow more than pool balance");
//     }

//     function testReturnAmountRevert() public {
//         testPoolBalance();

//         // # --------------------------------------------------------------------//
//         // # Should not be able to flash loan due to lack of funds # //
//         // # --------------------------------------------------------------------//

//         // mint fee and enough tokens so it can payback lender
//         shield.mint(address(badReceiver), LIQUIDITY / 10);

//         // retrieve previous balance
//         uint256 previousBalance = shield.balanceOf(address(badReceiver));

//         // approve
//         vm.prank(address(badReceiver));
//         shield.approve(address(protectionPool), type(uint256).max);

//         uint256 fee = protectionPool.flashFee(address(shield), LIQUIDITY);

//         // won't error since bad receiver doesn't have enough tokens to payback
//         // vm.expectRevert(FlashLoanPool__NotPaidBack.selector);
//         vm.expectRevert("ERC20: transfer amount exceeds balance");
//         protectionPool.flashLoan(badReceiver, address(shield), LIQUIDITY, data);
//         assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY);

//         // transaction reverts, keeps previous balance
//         assertEq(shield.balanceOf(address(badReceiver)), previousBalance);

//         console.log(unicode"✅ Not flash loan due to lack of funds");

//     }

//     function testReturnAmountWithLiquidity() public {
//         testPoolBalance();

//         // # --------------------------------------------------------------------//
//         // # Should be able to flash loan with current funds despite loss # //
//         // # --------------------------------------------------------------------//

//         // mint fee and enough tokens so it can payback lender
//         shield.mint(address(badReceiver), LIQUIDITY / 1000 + LIQUIDITY / 10);

//         // retrieve previous balance
//         uint256 previousBalance = shield.balanceOf(address(badReceiver));

//         // approve
//         vm.prank(address(badReceiver));
//         shield.approve(address(protectionPool), type(uint256).max);

//         uint256 fee = protectionPool.flashFee(address(shield), LIQUIDITY);

//         // won't error since bad receiver isn't able to payback from arbitrage attempt
//         // vm.expectRevert(FlashLoanPool__NotPaidBack.selector);

//         // won't error because it has tokens to payback
//         // vm.expectRevert("ERC20: transfer amount exceeds balance");
//         vm.expectEmit(true, true, false, true);
//         emit FlashLoanBorrowed(
//             address(protectionPool),
//             address(badReceiver),
//             address(shield),
//             LIQUIDITY,
//             fee
//         );
//         protectionPool.flashLoan(badReceiver, address(shield), LIQUIDITY, data);

//         console.log(shield.balanceOf(address(protectionPool)));
//         console.log(LIQUIDITY + fee);
//         console.log(shield.balanceOf(address(badReceiver)));
//         console.log(previousBalance);
//         console.log(
//             IERC20(policyCenter.usdc()).balanceOf(address(badReceiver))
//         );
//         assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY + fee);

//         // New balance is higher then previous balance because it used previosuly
//         // owned capital to payback loan
//         assertEq(shield.balanceOf(address(badReceiver)) < previousBalance, true);

//         console.log(unicode"✅ Pay for flash loan losing funds");

//     }

//     function testFlashLoanArbitrage() public {
//         testPoolBalance();

//         // # --------------------------------------------------------------------//
//         // # Should be able to flash loan with no arbitrage # //
//         // # --------------------------------------------------------------------//

//         // we want to borrow and return right away
//         shield.mint(address(arbitrageReceiver), LIQUIDITY / 1000);
//         uint256 previousBalance = shield.balanceOf(address(arbitrageReceiver));
//         vm.prank(address(arbitrageReceiver));
//         shield.approve(address(protectionPool), type(uint256).max);
//         uint256 fee = protectionPool.flashFee(address(shield), LIQUIDITY);
//         protectionPool.flashLoan(
//             arbitrageReceiver,
//             address(shield),
//             LIQUIDITY,
//             data
//         );
//         assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY + fee);
//         assertEq(
//             shield.balanceOf(address(arbitrageReceiver)) > previousBalance,
//             true
//         );

//         console.log(unicode"✅ Flash loan with arbitrage");

//     }

//     function testFlashLoanNoArbitrage() public {
//         // setup pool
//         testPoolBalance();
//         // # --------------------------------------------------------------------//
//         // # Should be able to flash loan with no arbitrage # //
//         // # --------------------------------------------------------------------//

//         // we want to borrow and return right away and not make a profit
//         shield.mint(address(receiver), LIQUIDITY / 1000);
//         vm.prank(address(receiver));
//         shield.approve(address(protectionPool), type(uint256).max);
//         uint256 fee = protectionPool.flashFee(address(shield), LIQUIDITY);

//         vm.expectEmit(true, true, false, true);
//         emit FlashLoanBorrowed(
//             address(protectionPool),
//             address(receiver),
//             address(shield),
//             LIQUIDITY,
//             fee
//         );
//         protectionPool.flashLoan(receiver, address(shield), LIQUIDITY, data);
//         // protection pool receives fee and received liquidity
//         assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY + fee);
//         // paid fee and returned loan, empty balance. No profit
//         assertEq(shield.balanceOf(address(arbitrageReceiver)), 0);

//         console.log(unicode"✅ Flash loan with no arbitrage");

//     }

//     // TODO: fix fuzzing
//     // function testFuzzFlashLoan(uint256 _borrowAmount)
//     //     public
//     // {   
//     //     testPoolBalance();
//     //     vm.assume(_borrowAmount > 0);
//     //     vm.assume(_borrowAmount <= shield.balanceOf(address(protectionPool)));
//     //     uint256 fee = protectionPool.flashFee(address(shield), _borrowAmount);

//     //     shield.mint(address(receiver), LIQUIDITY / 1000);
//     //     vm.prank(address(receiver));
//     //     shield.approve(address(protectionPool), type(uint256).max);

//     //     vm.expectEmit(true, true, false, true);
//     //     emit FlashLoanBorrowed(
//     //         address(protectionPool),
//     //         address(receiver),
//     //         address(shield),
//     //         _borrowAmount,
//     //         fee
//     //     );
//     //     protectionPool.flashLoan(receiver, address(shield), LIQUIDITY, data);
//     //     assertEq(shield.balanceOf(address(protectionPool)), LIQUIDITY + fee);
//     // }
// }
