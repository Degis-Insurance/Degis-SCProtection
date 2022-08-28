// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "forge-std/Vm.sol";
// import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
// import "src/pools/priorityPool/PriorityPoolFactory.sol";
// import "src/pools/protectionPool/ProtectionPool.sol";
// import "src/pools/PremiumRewardPool.sol";
// import "src/pools/PayoutPool.sol";
// import "src/reward/WeightedFarmingPool.sol";

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

// contract setAddressesTest is Test {
//     PriorityPoolFactory public priorityPoolFactory;
//     ProtectionPool public protectionPool;
//     PolicyCenter public policyCenter;
//     WeightedFarmingPool public weightedFarmingPool;
//     PayoutPool public payoutPool;
//     PremiumRewardPool public premiumRewardPool;
//     OnboardProposal public onboardProposal;
//     IncidentReport public incidentReport;
//     MockSHIELD public shield;
//     MockDEG public deg;
//     MockVeDEG public vedeg;
//     PriorityPool public insurancePool;
//     MockExchange public exchange;
//     Executor public executor;
//     ERC20 public ptp;

//     address public alice = address(0x1337);
//     address public bob = address(0x133702);
//     address public carol = address(0x133703);

//     address public pool1;

//     function setUp() public {
//         shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
//         deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
//         vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
//         ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);

//         // deploy contracts
//         exchange = new MockExchange();
//         protectionPool = new ProtectionPool(
//             address(deg),
//             address(vedeg),
//             address(shield)
//         );
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
//         incidentReport = new IncidentReport(
//             address(deg),
//             address(vedeg),
//             address(shield)
//         );
//         onboardProposal = new OnboardProposal(
//             address(deg),
//             address(vedeg),
//             address(shield)
//         );
//         priorityPoolFactory.setPolicyCenter(address(policyCenter));
//         policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
//         policyCenter.setExchange(address(exchange));
//         // required to provide liquidity
//         protectionPool.setPolicyCenter(address(policyCenter));

//         shield.transfer(address(this), 10000 ether);
//         shield.approve(address(policyCenter), 1000000 ether);
//         // pools require initial liquidity input to Protection pool
//         policyCenter.provideLiquidity(10000 ether);

//         // setup weighted farming pool
//         weightedFarmingPool = new WeightedFarmingPool(
//             address(premiumRewardPool)
//         );
//         weightedFarmingPool.setPolicyCenter(address(policyCenter));
//         priorityPoolFactory.setWeightedFarmingPool(
//             address(weightedFarmingPool)
//         );
//         policyCenter.setWeightedFarmingPool(address(weightedFarmingPool));

//         pool1 = priorityPoolFactory.deployPool(
//             "Platypus",
//             address(ptp),
//             1000 ether,
//             260
//         );
//     }

//     function testSetPolicyCenterAddress() public {
//         priorityPoolFactory.setPolicyCenter(address(policyCenter));
//         console.log(priorityPoolFactory.policyCenter());
//         assertEq(
//             priorityPoolFactory.policyCenter() == address(policyCenter),
//             true
//         );
//     }

//     function testSetPriorityPoolFactoryAddress() public {
//         policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
//         console.log(policyCenter.priorityPoolFactory());
//         assertEq(
//             policyCenter.priorityPoolFactory() == address(priorityPoolFactory),
//             true
//         );
//     }

//     function testSetPremiumRewardPoolAddress() public {
//         priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));
//         console.log(priorityPoolFactory.premiumRewardPool());
//         assertEq(
//             priorityPoolFactory.premiumRewardPool() ==
//                 address(premiumRewardPool),
//             true
//         );
//     }

//     function testSetPriorityPoolFactory() public {
//         onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));
//         assertEq(
//             address(onboardProposal.priorityPoolFactory()) ==
//                 address(priorityPoolFactory),
//             true
//         );
//     }

//     function testSetExecutor() public {
//         policyCenter.setExecutor(address(executor));
//         assertEq(policyCenter.executor() == address(executor), true);
//     }

//     function testSetPolicyCenterNotOwner() public {
//         // use a non owner address to make sure it's not allowed to set address
//         vm.prank(address(0x0000abcdef));
//         vm.expectRevert("Ownable: caller is not the owner");
//         priorityPoolFactory.setPolicyCenter(address(policyCenter));
//     }

//     function testSetPriorityPoolFactoryNotOwner() public {
//         // use a non owner address to make sure it's not allowed to set address
//         vm.prank(address(0x0000abcdef));
//         vm.expectRevert("Ownable: caller is not the owner");
//         onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));
//     }

//     function testSetExecutorNotOwner() public {
//         // use a random address to make sure it doesn't work
//         vm.prank(address(0x0000abcdef));
//         vm.expectRevert("Ownable: caller is not the owner");
//         // onboardProposal.setExecutor(address(executor));
//     }

//     // test setting pool max capacity
//     function testSetMaxCapacity() public {
//         PriorityPool(pool1).setMaxCapacity(false, 90);
//         assertEq(PriorityPool(pool1).maxCapacity() == 90, true);
//     }

//     function testGetMaxCapacity() public {
//         assertEq(PriorityPool(pool1).maxCapacity() == 100, true);
//     }

//     function testSetExecutorPriorityPool() public {
//         PriorityPool(pool1).setExecutor(address(executor));
//         assertEq(PriorityPool(pool1).executor() == address(executor), true);
//     }

//     function testSetIncidentReport() public {
//         PriorityPool(pool1).setIncidentReport(address(incidentReport));
//         assertEq(
//             PriorityPool(pool1).incidentReport() == address(incidentReport),
//             true
//         );
//     }
// }
