// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ProtectionPool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/OnboardProposal.sol";
import "src/voting/IncidentReport.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IProtectionPool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

/** 
@notice Tests initial deployment for most contracts.
 */
contract InitialContractDeploymentTest is Test {
    InsurancePoolFactory public insurancePoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    ERC20Mock public ptp;
    InsurancePool public insurancePool;
    Executor public executor;

    function setUp() public {}

    function testDeployShield() public {
        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");
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
        protectionPool = new ProtectionPool(
            address(0),
            address(0),
            address(0)
        );
        assertEq(
            keccak256(bytes(protectionPool.name())) ==
                keccak256(bytes("ProtectionPool")),
            true
        );
    }

    function testDeployExecutor() public {
        executor = new Executor();
        assertEq(executor.proposalBuffer() == 0 days, true);
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
}

/** 
@notice Tests secondary deployment for most contracts since they are dependent on other contracts.
 */
contract SecondaryContractDeploymentTest is Test {
    InsurancePoolFactory public insurancePoolFactory;
    OnboardProposal public onboardProposal;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    Executor public executor;
    Exchange public exchange;

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
        protectionPool = new ProtectionPool(
            address(deg),
            address(0),
            address(0)
        );
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
        insurancePoolFactory = new InsurancePoolFactory(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );
        assertEq(insurancePoolFactory.poolCounter() == 0, true);
    }

    function testDeployInsurancePool() public {
        // To deploy an insurance pool, a minnimum liquidity must be provided to protection pool
        policyCenter.provideLiquidity(10000 ether);
        // Insurance pools are created by the insurance pool factory.
        // it is dependent on deg, protectionPool,
        // policyCenter and insurancePoolFactory being deployed.
        insurancePoolFactory = new InsurancePoolFactory(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );

        policyCenter = new PolicyCenter(
            address(0),
            address(0),
            address(deg),
            address(protectionPool)
        );
        exchange = new Exchange();
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        address pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            10000,
            100
        );
        console.log(pool1);
    }
}
