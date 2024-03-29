// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "forge-std/Vm.sol";
// import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
// import "src/pools/priorityPool/PriorityPoolFactory.sol";
// import "src/pools/protectionPool/ProtectionPool.sol";
// import "src/pools/PayoutPool.sol";
// import "src/reward/WeightedFarmingPool.sol";
// import "src/pools/PremiumRewardPool.sol";
// import "src/core/PolicyCenter.sol";
// import "src/voting/onboardProposal/OnboardProposal.sol";
// import "src/voting/incidentReport/IncidentReport.sol";
// import "src/mock/MockSHIELD.sol";
// import "src/mock/MockDEG.sol";
// import "src/mock/MockVeDEG.sol";
// import "src/core/Executor.sol";
// import "src/mock/MockExchange.sol";

// import "src/interfaces/IPriorityPool.sol";
// import "src/interfaces/IPolicyCenter.sol";
// import "src/interfaces/IProtectionPool.sol";
// import "src/interfaces/IPriorityPool.sol";
// import "src/interfaces/IOnboardProposal.sol";
// import "src/interfaces/IExecutor.sol";

// contract NoLiquidationTest is Test {
//     PriorityPoolFactory public priorityPoolFactory;
//     ProtectionPool public protectionPool;
//     PolicyCenter public policyCenter;
//     WeightedFarmingPool public weightedFarmingPool;
//     PayoutPool public payoutPool;
//     PremiumRewardPool public premiumRewardPool;
//     OnboardProposal public onboardProposal;
//     MockSHIELD public shield;
//     MockDEG public deg;
//     MockVeDEG public vedeg;
//     PriorityPool public insurancePool;
//     IncidentReport public incidentReport;
//     MockExchange public exchange;
//     Executor public executor;
//     ERC20 public ptp;
//     ERC20 public yeti;

//     // defines users
//     address public alice = address(0x1337);
//     address public bob = address(0x133702);
//     address public carol = address(0x133703);
//     // pool1 address
//     address public pool1;
//     address public pool2;

//     function setUp() public {
//         shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
//         deg = new MockDEG(10000000 ether, "Degis", 18, "DEG");
//         vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
//         ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
//         yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);

//         // deploy contracts
//         protectionPool = new ProtectionPool(
//             address(deg),
//             address(vedeg),
//             address(shield)
//         );
//         payoutPool = new PayoutPool();
//         priorityPoolFactory = new PriorityPoolFactory(
//             address(deg),
//             address(vedeg),
//             address(shield),
//             address(protectionPool)
//         );
//         premiumRewardPool = new PremiumRewardPool(
//             address(shield),
//             address(priorityPoolFactory),
//             address(protectionPool)
//         );
//         priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));
//         policyCenter = new PolicyCenter(
//             address(deg),
//             address(vedeg),
//             address(shield),
//             address(protectionPool)
//         );
//         executor = new Executor();
//         onboardProposal = new OnboardProposal(
//             address(deg),
//             address(vedeg),
//             address(shield)
//         );
//         incidentReport = new IncidentReport(
//             address(deg),
//             address(vedeg),
//             address(shield)
//         );

//         // deploy exchange and supply tokens can be swapped during buy coverage split
//         exchange = new MockExchange();
//         deg.transfer(address(exchange), 1000 ether);
//         shield.transfer(address(exchange), 1000 ether);
//         ptp.transfer(address(exchange), 1000 ether);

//         priorityPoolFactory.setPolicyCenter(address(policyCenter));

//         priorityPoolFactory.setProtectionPool(address(protectionPool));
//         priorityPoolFactory.setPolicyCenter(address(policyCenter));
//         priorityPoolFactory.setExecutor(address(executor));

//         protectionPool.setPolicyCenter(address(policyCenter));

//         protectionPool.setIncidentReport(address(incidentReport));
//         protectionPool.setPolicyCenter(address(policyCenter));

//         policyCenter.setExecutor(address(executor));

//         policyCenter.setProtectionPool(address(protectionPool));
//         policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
//         policyCenter.setExchange(address(exchange));

//         // onboardProposal.setExecutor(address(executor));
//         onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));

//         incidentReport.setPriorityPoolFactory(address(priorityPoolFactory));

//         executor.setOnboardProposal(address(onboardProposal));

//         executor.setPriorityPoolFactory(address(priorityPoolFactory));

//         weightedFarmingPool = new WeightedFarmingPool(
//             address(premiumRewardPool)
//         );
//         weightedFarmingPool.setPolicyCenter(address(policyCenter));
//         priorityPoolFactory.setWeightedFarmingPool(
//             address(weightedFarmingPool)
//         );

//         policyCenter.setWeightedFarmingPool(address(weightedFarmingPool));

//         shield.transfer(address(this), 10000 ether);
//         shield.approve(address(policyCenter), 10000 ether);
//         // pools require initial liquidity input to Protection pool
//         policyCenter.provideLiquidity(10000 ether);

//         pool1 = priorityPoolFactory.deployPool(
//             "Platypus",
//             address(ptp),
//             1000 ether,
//             260
//         );

//         PriorityPool(pool1).setExecutor(address(executor));
//         PriorityPool(pool1).setPolicyCenter(address(policyCenter));

//         deg.transfer(address(this), 1000 ether);
//         deg.transfer(address(policyCenter), 100);
//         vedeg.transfer(alice, 3000 ether);
//         vedeg.transfer(bob, 2000 ether);
//         vedeg.transfer(carol, 3000 ether);
//         // mint and approve tokens for pool1 and pool2
//         ptp.approve(address(policyCenter), 10000 ether);
//         yeti.approve(address(policyCenter), 10000 ether);

//         // transfer shield to liquidity providers
//         shield.transfer(alice, 100 ether);
//         shield.transfer(bob, 100 ether);
//         shield.transfer(carol, 100 ether);

//         // transfer deg to users
//         deg.transfer(alice, 10 ether);
//         deg.transfer(bob, 10 ether);
//         deg.transfer(carol, 10 ether);

//         // transfer ptp to carol
//         // to buy coverage
//         ptp.transfer(carol, 100 ether);
//         // approve ptp usage for carol
//         vm.prank(carol);
//         ptp.approve(address(policyCenter), 1000000 ether);

//         // provide liquidity by users
//         // alice provides liquidity to pool 1
//         vm.prank(alice);
//         shield.approve(address(policyCenter), 10000 ether);
//         vm.prank(alice);
//         policyCenter.stakeLiquidity(1, 1 ether);

//         // bob provides liqudity to reinsurance pool
//         vm.prank(bob);
//         shield.approve(address(policyCenter), 10000 ether);
//         vm.prank(bob);
//         policyCenter.provideLiquidity(1 ether);
//         vm.prank(carol);
//         shield.approve(address(policyCenter), 1000000 ether);

//         // carol buys coverage from pool 1
//         (uint256 price, uint256 coverLength) = PriorityPool(pool1).coverPrice(
//             10 ether,
//             3
//         );
//         vm.prank(carol);
//         ptp.approve(address(policyCenter), 1000000 ether);
//         vm.prank(carol);
//         policyCenter.buyCover(1, 10 ether, 3, price);
//         vm.warp(30 days);
//     }
// }
