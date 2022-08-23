// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/pools/protectionPool/ProtectionPool.sol";
import "src/pools/PremiumRewardPool.sol";
import "src/pools/PayoutPool.sol";
import "src/reward/WeightedFarmingPool.sol";

import "src/core/PolicyCenter.sol";
import "src/voting/onboardProposal/OnboardProposal.sol";
import "src/voting/incidentReport/IncidentReport.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";

import "src/interfaces/IPriorityPool.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IPayoutPool.sol";
import "src/interfaces/IProtectionPool.sol";
import "src/interfaces/IPriorityPool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IPremiumRewardPool.sol";
import "src/interfaces/IExecutor.sol";

/** 
@notice Tests initial deployment for most contracts.
 */
contract InitialContractDeploymentTest is Test {
    PriorityPoolFactory public priorityPoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    WeightedFarmingPool public weightedFarmingPool;
    PremiumRewardPool public premiumRewardPool;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    ERC20Mock public ptp;
    PriorityPool public insurancePool;
    Executor public executor;
    PayoutPool public payoutPool;

    function setUp() public {}

    function testDeployShield() public {
        shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
        assertEq(
            keccak256(bytes(shield.name())) == keccak256(bytes("Shield")),
            true
        );
    }

    function testDeployDEG() public {
        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        assertEq(
            keccak256(bytes(deg.name())) == keccak256(bytes("Degis")),
            true
        );
    }

    function testDeployVeDEG() public {
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        assertEq(
            keccak256(bytes(vedeg.name())) == keccak256(bytes("veDegis")),
            true
        );
    }

    function testDeployPTP() public {
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);

        assertEq(
            keccak256(bytes(ptp.name())) == keccak256(bytes("Platypus")),
            true
        );
    }

    function testDeployProtectionPool() public {
        protectionPool = new ProtectionPool(address(0), address(0), address(0));
        assertEq(
            keccak256(bytes(protectionPool.name())) ==
                keccak256(bytes("ProtectionPool")),
            true
        );
    }

    function testDeployOnboardProposal() public {
        onboardProposal = new OnboardProposal(
            address(0),
            address(0),
            address(0)
        );
        assertEq(address(onboardProposal) == address(0), false);
    }

    function testDeployIncidentReport() public {
        incidentReport = new IncidentReport(address(0), address(0), address(0));
        assertEq(address(incidentReport) == address(0), false);
    }

    function testDeployPayoutPool() public {
        payoutPool = new PayoutPool();
    }
}

/** 
@notice Tests secondary deployment for most contracts since they are dependent on other contracts.
 */
contract SecondaryContractDeploymentTest is Test {
    PriorityPoolFactory public priorityPoolFactory;
    OnboardProposal public onboardProposal;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    WeightedFarmingPool public weightedFarmingPool;
    PremiumRewardPool public premiumRewardPool;
    Executor public executor;
    Exchange public exchange;
    PayoutPool public payoutPool;

    // tokens
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;

    ERC20 public ptp;

    function setUp() public {
        // Policy Center, Factory and Insurrance Pool require deg, a third party token
        // and the protectionPool already deployed.
        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);
        shield = new MockSHIELD(10000000 ether, "Shield", 18, "SHIELD");
        protectionPool = new ProtectionPool(
            address(deg),
            address(0),
            address(0)
        );

        protectionPool.setPolicyCenter(address(policyCenter));
    }

    function testDeployPolicyCenter() public {
        // Policy center manages user interactions with insurance pools.
        // It is dependent on deg and protectionPool being deployed.
        policyCenter = new PolicyCenter(
            address(deg),
            address(0),
            address(0),
            address(protectionPool)
        );
        assertEq(
            policyCenter.protectionPool() == address(protectionPool),
            true
        );
    }

    function testDeployFactory() public {
        // Factory creates insurance pools.
        // It is dependent on deg and protectionPool being deployed.
        priorityPoolFactory = new PriorityPoolFactory(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );

        assertEq(priorityPoolFactory.poolCounter() == 0, true);
    }

    function testDeployPremiumRewardPool() public {
        priorityPoolFactory = new PriorityPoolFactory(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );
        premiumRewardPool = new PremiumRewardPool(
            address(shield),
            address(priorityPoolFactory),
            address(protectionPool)
        );
        assertEq(premiumRewardPool.shield(), address(shield));
    }

    function testDeployWeightedFarmingPool() public {
        weightedFarmingPool = new WeightedFarmingPool(
            address(premiumRewardPool)
        );
        assertEq(
            weightedFarmingPool.premiumRewardPool(),
            address(premiumRewardPool)
        );
    }

    function testDeployPriorityPool() public {
        policyCenter = new PolicyCenter(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );
        policyCenter.setProtectionPool(address(protectionPool));
        protectionPool.setPolicyCenter(address(policyCenter));

        shield.transfer(address(this), 1000 ether);
        shield.approve(address(policyCenter), 1000 ether);
        // To deploy an insurance pool, a minnimum liquidity must be provided to protection pool
        policyCenter.provideLiquidity(1000 ether);
        // Insurance pools are created by the insurance pool factory.
        // it is dependent on deg, protectionPool,
        // policyCenter and priorityPoolFactory being deployed.
        priorityPoolFactory = new PriorityPoolFactory(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );

        premiumRewardPool = new PremiumRewardPool(
            address(shield),
            address(priorityPoolFactory),
            address(protectionPool)
        );

        weightedFarmingPool = new WeightedFarmingPool(
            address(premiumRewardPool)
        );
        weightedFarmingPool.setPolicyCenter(address(policyCenter));

        policyCenter = new PolicyCenter(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );
        exchange = new Exchange();
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExchange(address(exchange));
        priorityPoolFactory.setPremiumRewardPool(address(premiumRewardPool));
        priorityPoolFactory.setWeightedFarmingPool(
            address(weightedFarmingPool)
        );
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        address pool1 = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            10000,
            100
        );
        console.log(pool1);
    }
}
