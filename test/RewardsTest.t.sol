// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.15;

// import "./utils/ContractSetupBaseTest.sol";

// import "src/interfaces/IPolicyCenter.sol";

// import "src/core/interfaces/PolicyCenterEventError.sol";
// import "src/pools/protectionPool/ProtectionPoolEventError.sol";
// import "src/pools/priorityPool/PriorityPoolEventError.sol";
// import "src/core/interfaces/PolicyCenterDependencies.sol";
// import "src/voting/incidentReport/IncidentReportParameters.sol";
// import "src/voting/onboardProposal/OnboardProposalParameters.sol";

// import "forge-std/console.sol";

// contract RewardsTest is
//     PolicyCenterEventError,
//     ProtectionPoolEventError,
//     PriorityPoolEventError,
//     WeightedFarmingPoolEventError,
//     OnboardProposalParameters,
//     IncidentReportParameters,
//     ContractSetupBaseTest
// {
//     address internal ALICE = mkaddr("Alice");
//     address internal BOB = mkaddr("Bob");
//     address internal CHARLIE = mkaddr("Charlie");

//     uint256 internal constant CAPACITY_1 = 40;

//     uint256 internal constant JOE_ID = 1;

//     uint256 internal constant PREMIUMRATIO_1 = 200;

//     uint256 internal constant COVER_AMOUNT = 1e18;
//     uint256 internal constant PAYOUT = 1e18;
//     uint256 internal constant LIQUIDITY_UNIT = 100e6;
//     uint256 internal constant MIN_COVER_AMOUNT = 100e6;
//     uint256 internal constant SCALE = 1e12;

//     uint256 internal constant LIQUIDITY = 1000 ether;

//     // uint256 internal constant VOTE_FOR = 1;
//     // uint256 internal constant VOTE_AGAINST = 2;
//     uint256 internal constant VOTE_AMOUNT = 100 ether;

//     uint256 internal constant PROPOSAL_VOTE_TIME = 0;
//     uint256 internal constant INCIDENT_VOTE_TIME = PENDING_PERIOD;

//     uint256 internal constant PROPOSAL_SETTLE_TIME =
//         PROPOSAL_VOTE_TIME + PROPOSAL_VOTING_PERIOD;
//     uint256 internal constant INCIDENT_SETTLE_TIME =
//         INCIDENT_VOTE_TIME + INCIDENT_VOTING_PERIOD;

//     IPriorityPool internal joePool;

//     MockERC20 internal joe;
//     MockERC20 internal usdc;

//     address internal joeLPAddress;

//     address internal crJoeAddress;

//     function setUp() public {
//         setUpContracts();

//         // Deploy usdc
//         usdc = new MockERC20("USDC", "USDC", 18);

//         // Set USDC address to current mainnet address
//         bytes memory bytecode = address(usdc).code;
//         vm.etch(policyCenter.USDC(), bytecode);

//         vm.warp(0);

//         // Deploy three protocol tokens
//         joe = new MockERC20("JoeToken", "JOE", 18);

//         // Deploy three priority pools
//         joePool = IPriorityPool(
//             priorityPoolFactory.deployPool(
//                 "TraderJoe",
//                 address(joe),
//                 CAPACITY_1,
//                 PREMIUMRATIO_1
//             )
//         );

//         joeLPAddress = joePool.currentLPAddress();

//         // Mint veDEG for voters
//         veDEG.mint(ALICE, 100 ether);
//         veDEG.mint(BOB, 100 ether);

//         // Fund exchange
//         deg.mintDegis(address(exchange), 1000 ether);
//         shield.mint(address(exchange), 1000 ether);
//         MockERC20(policyCenter.USDC()).mint(address(exchange), 1000 ether * SCALE);
//         joe.mint(address(exchange), 1000 ether * SCALE);
//     }

//     function _provideLiquidity(address _user) private {
//         shield.mint(_user, LIQUIDITY);
//         vm.prank(_user);
//         shield.approve(address(policyCenter), type(uint256).max);
//         vm.prank(_user);
//         policyCenter.provideLiquidity(LIQUIDITY);
//     }

//     function _stake(address _user) private {
//         _provideLiquidity(_user);
//         vm.prank(_user);
//         protectionPool.approve(address(policyCenter), type(uint256).max);
//         vm.prank(_user);
//         policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);
//     }

//     function _buyCover(address _user) internal {
//         vm.warp(0);
//         (uint256 price, uint256 length) = joePool.coverPrice(COVER_AMOUNT, 3);
//         vm.prank(_user);
//         joe.approve(address(policyCenter), type(uint256).max);
//         joe.mint(_user, price * 11 / 10);
//         vm.prank(_user);
//         // Get Joe cover right address and buy cover
//         crJoeAddress = policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, price * 11 / 10);
//     }


//     function _truthfulReport(uint256 time, uint256 reportId) internal {
//         vm.warp(time + 0);
//         vm.prank(CHARLIE);
//         incidentReport.report(JOE_ID, PAYOUT);
//         vm.warp(time + INCIDENT_VOTE_TIME);
//         vm.prank(CHARLIE);
//         incidentReport.startVoting(reportId);
//         vm.prank(ALICE);
//         incidentReport.vote(reportId, VOTE_FOR, VOTE_AMOUNT);
//         vm.prank(BOB);
//         incidentReport.vote(reportId, VOTE_FOR, VOTE_AMOUNT);
//         vm.warp(time + INCIDENT_SETTLE_TIME);
//         incidentReport.settle(reportId);
//         executor.executeReport(reportId);
//     }

//     function testWeightedFarmingPool() public {
//         _provideLiquidity(CHARLIE);
//         vm.prank(CHARLIE);
//         protectionPool.approve(address(policyCenter), LIQUIDITY * 2);
//         _buyCover(ALICE);
//         // _buyCover(BOB);

//         MockERC20(policyCenter.USDC()).approve(address(policyCenter), type(uint256).max);
//         deg.mintDegis(CHARLIE, REPORT_THRESHOLD);

//         // # --------------------------------------------------------------------//
//         // # Should not be able to claim reward before month passed # //
//         // # --------------------------------------------------------------------//

//         uint256 reward = farmingPool.pendingReward(JOE_ID, CHARLIE);
//         assertEq(reward, 0);

//         vm.prank(CHARLIE);
//         vm.expectRevert(WeightedFarmingPool__NoPendingRewards.selector);
//         farmingPool.harvest(JOE_ID, CHARLIE);

//         console.log(unicode"✅ Not harvest before month passed");

//         uint256 snapshot_1 = vm.snapshot();
//         vm.warp(31 days);

//         // # --------------------------------------------------------------------//
//         // # Should not be able to harvest if did not stake # //
//         // # --------------------------------------------------------------------//

//         vm.prank(CHARLIE);
//         vm.expectRevert(WeightedFarmingPool__NoPendingRewards.selector);
//         farmingPool.harvest(JOE_ID, CHARLIE);

//         console.log(unicode"✅ Not harvest if did not stake");

//         vm.revertTo(snapshot_1);

//         vm.prank(CHARLIE);
//         policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

//         vm.warp(31 days);
//         uint256 snapshot_2 = vm.snapshot();

//         // # --------------------------------------------------------------------//
//         // # Should not be able to harvest inexistent pool # //
//         // # --------------------------------------------------------------------//

//         vm.prank(CHARLIE);
//         vm.expectRevert(WeightedFarmingPool__InexistentPool.selector);
//         farmingPool.harvest(2, CHARLIE);

//         console.log(unicode"✅ Not harvest if inexistent pool");

//         // # --------------------------------------------------------------------//
//         // # Should be able to claim reward # //
//         // # --------------------------------------------------------------------//

//         reward = farmingPool.pendingReward(JOE_ID, CHARLIE);

//         vm.prank(CHARLIE);
//         vm.expectEmit(false, false, false, true);
//         // harvest does not represent correctly the expected emitted reward
//         emit Harvest(JOE_ID, CHARLIE, CHARLIE, 547769660000000000000);
//         farmingPool.harvest(JOE_ID, CHARLIE);

//         console.log(unicode"✅ harvest reward");

//         // # --------------------------------------------------------------------//
//         // # Should be able to harvest to another address # //
//         // # --------------------------------------------------------------------//
        
//         vm.revertTo(snapshot_2);
//         uint256 snapshot_3 = vm.snapshot();

//         reward = farmingPool.pendingReward(JOE_ID, CHARLIE);

//         vm.prank(CHARLIE);
//         vm.expectEmit(false, false, false, true);
//         emit Harvest(JOE_ID, CHARLIE, BOB, reward);
//         farmingPool.harvest(JOE_ID, BOB);

//         console.log(unicode"✅ harvest to another address");

//         // # --------------------------------------------------------------------//
//         // # Should not be able to harvest if unstaked # //
//         // # --------------------------------------------------------------------//

//         vm.prank(CHARLIE);
//         policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

//         vm.warp(62 days);

//         vm.prank(CHARLIE);
//         vm.expectRevert(WeightedFarmingPool__NoPendingRewards.selector);
//         farmingPool.harvest(JOE_ID, CHARLIE);

//         console.log(unicode"✅ Not harvest if unstaked");

//         vm.revertTo(snapshot_3);

//         _truthfulReport(35 days, 1);

//         // # --------------------------------------------------------------------//
//         // # Should be able to harvest after report # //
//         // # --------------------------------------------------------------------//
//         reward = farmingPool.pendingReward(JOE_ID, CHARLIE);

//         // reward should be the entire amount of what was paid to the pool
//         vm.prank(CHARLIE);
//         vm.expectEmit(false, false, false, true);
//         emit Harvest(JOE_ID, CHARLIE, CHARLIE, reward);
//         farmingPool.harvest(JOE_ID, ALICE);

//         console.log(unicode"✅ harvest after report");

//     }

// }
