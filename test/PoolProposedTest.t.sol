// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/pools/protectionPool/ProtectionPool.sol";
import "src/pools/PayoutPool.sol";
import "src/pools/PremiumRewardPool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/onboardProposal/OnboardProposal.sol";
import "src/voting/incidentReport/IncidentReport.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";
import "src/mock/MockExchange.sol";

import "src/interfaces/IPriorityPool.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IProtectionPool.sol";
import "src/interfaces/IPriorityPool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

contract ClaimPayoutTest is Test {
    PriorityPoolFactory public priorityPoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    PayoutPool public payoutPool;
    PremiumRewardPool public premiumRewardPool;

    OnboardProposal public onboardProposal;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    IncidentReport public incidentReport;
    PriorityPool public insurancePool;
    Exchange public exchange;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;

    uint256 public constant VOTE_FOR = 1;
    uint256 public constant VOTE_AGAINST = 2;
    uint256 public constant POOL_ID = 1;
    uint256 public constant PROPOSAL_ID = 1;

    uint256 public constant START_TIME = 1;
    uint256 public constant VOTE_PERIOD = 3 days;
    uint256 public constant EXECUTE_PERIOD = 6 days;

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;
    address public pool2;

    function setUp() public {
        shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000000 ether, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        yeti = new ERC20Mock("Yeti", "YETI", address(this), 10000 ether);
        vm.label(address(yeti), "yeti");
        console.log(yeti.balanceOf(address(this)));

        // deploy contracts
        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );
        priorityPoolFactory = new PriorityPoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool),
            address(payoutPool)
        );
        premiumRewardPool = new PremiumRewardPool(
            address(shield),
            address(priorityPoolFactory), 
            address(protectionPool)
        );
        priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));
        policyCenter = new PolicyCenter(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );
        executor = new Executor();
        incidentReport = new IncidentReport(
            address(deg),
            address(vedeg),
            address(shield)
        );
        onboardProposal = new OnboardProposal(
            address(deg),
            address(vedeg),
            address(shield)
        );

        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000 ether);
        shield.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);

        priorityPoolFactory.setPolicyCenter(address(policyCenter));

        priorityPoolFactory.setProtectionPool(address(protectionPool));
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setExecutor(address(executor));

        protectionPool.setPolicyCenter(address(policyCenter));
        protectionPool.setIncidentReport(address(incidentReport));
        protectionPool.setPolicyCenter(address(policyCenter));

        policyCenter.setExecutor(address(executor));
        policyCenter.setProtectionPool(address(protectionPool));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExchange(address(exchange));

        onboardProposal.setExecutor(address(executor));
        onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));

        incidentReport.setPolicyCenter(address(policyCenter));
        incidentReport.setProtectionPool(address(protectionPool));
        incidentReport.setPriorityPoolFactory(address(priorityPoolFactory));

        executor.setPolicyCenter(address(policyCenter));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setProtectionPool(address(protectionPool));
        executor.setPriorityPoolFactory(address(priorityPoolFactory));

        // pools require initial liquidity input to Protection pool
      //  policyCenter.provideLiquidity(10000 ether);

        pool1 = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            260
        );

        PriorityPool(pool1).setExecutor(address(executor));
        PriorityPool(pool1).setPolicyCenter(address(policyCenter));

        // fund exchange
        deg.transfer(address(exchange), 1000 ether);
        yeti.transfer(address(exchange), 1000 ether);
        ptp.transfer(address(exchange), 1000 ether);

        deg.transfer(address(this), 1000 ether);
        deg.transfer(address(onboardProposal), 1000 ether);
        deg.approve(address(onboardProposal), 10000 ether);

        vedeg.transfer(alice, 3000 ether);
        vedeg.transfer(bob, 3000 ether);
        vedeg.transfer(carol, 3000 ether);

        console.log("alice", vedeg.balanceOf(alice));

        // owner provides liquidity
        shield.transfer(address(this), 10000);
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.stakeLiquidityPoolToken(1, 10000);

        vm.warp(0);
        onboardProposal.propose("Yeti", address(yeti), 100, 1);

        vm.warp(START_TIME + VOTE_PERIOD);
        onboardProposal.startVoting(PROPOSAL_ID);

        vm.prank(alice);
        onboardProposal.vote(POOL_ID, VOTE_FOR, 3000 ether);
        vm.prank(bob);
        onboardProposal.vote(POOL_ID, VOTE_FOR, 3000 ether);
        vm.prank(carol);
        onboardProposal.vote(POOL_ID, VOTE_FOR, 3000 ether);

        vm.warp(START_TIME + VOTE_PERIOD + VOTE_PERIOD + 1);
        onboardProposal.settle(1);

        vm.warp(START_TIME + VOTE_PERIOD + EXECUTE_PERIOD + 2);
        pool2 = executor.executeProposal(1);

        PriorityPool(pool2).setExecutor(address(executor));
        PriorityPool(pool2).setPolicyCenter(address(policyCenter));
    }

    function testPresenceNewPool() public {
        // check if pool is created
        string memory name = PriorityPool(pool2).poolName();
        uint256 maxCapacity = PriorityPool(pool2).maxCapacity();

        assertEq(maxCapacity == 10000 ether, true);
    }

    function testProvideLiquidityNewPool() public {
        // approve shield usage for new pool
        shield.approve(address(policyCenter), 10000 ether);
        policyCenter.stakeLiquidityPoolToken(2, 10000);

        address currentLPToken = PriorityPool(pool1).currentLPAddress();
        assertEq(PriorityPoolToken(currentLPToken).totalSupply() == 10000, true);
        // check if owner has receive minted tokens
        assertEq(PriorityPoolToken(currentLPToken).balanceOf(address(this)) == 10000, true);
    }

    function testBuyCoverNewPool() public {
        yeti.approve(address(policyCenter), 10000 ether);
        (uint256 price, uint256 coverLength) = PriorityPool(pool2).coverPrice(10000 ether, 3);
        policyCenter.buyCover(2, 100 ether, 3, price);
        (uint256 amount, , ) = policyCenter.covers(2, address(this));
        assertEq(amount == 100 ether, true);
    }
}
