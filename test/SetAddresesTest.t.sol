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
import "src/mock/MockExchange.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IProtectionPool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

contract setAddressesTest is Test {
    InsurancePoolFactory public insurancePoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    OnboardProposal public onboardProposal;
    IncidentReport public incidentReport;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Exchange public exchange;
    Executor public executor;
    ERC20 public ptp;

    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);

    address public pool1;

    function setUp() public {
        shield = new MockSHIELD(10000 ether, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000 ether, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000 ether, "veDegis", 18, "veDeg");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000 ether);

        // deploy contracts
        exchange = new Exchange();
        protectionPool = new ProtectionPool(
            address(deg),
            address(vedeg),
            address(shield)
        );
        insurancePoolFactory = new InsurancePoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool)
        );
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
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        // required to provide liquidity
        protectionPool.setPolicyCenter(address(policyCenter));
        // pools require initial liquidity input to Protection pool
        policyCenter.provideLiquidity(10000 ether);

        pool1 = insurancePoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            260
        );
    }

    function testSetPolicyCenterAddress() public {
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        console.log(insurancePoolFactory.policyCenter());
        assertEq(
            insurancePoolFactory.policyCenter() == address(policyCenter),
            true
        );
    }

    function testSetInsurancePoolFactoryAddress() public {
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        console.log(policyCenter.insurancePoolFactory());
        assertEq(
            policyCenter.insurancePoolFactory() ==
                address(insurancePoolFactory),
            true
        );
    }

    function testSetInsurancePoolFactory() public {
        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));
        assertEq(
            onboardProposal.insurancePoolFactory() ==
                address(insurancePoolFactory),
            true
        );
    }

    function testSetExecutor() public {
        onboardProposal.setExecutor(address(executor));
        assertEq(onboardProposal.executor() == address(executor), true);
    }

    function testSetPolicyCenterNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
    }

    function testSetInsurancePoolFactoryNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));
    }

    function testSetExecutorNotOwner() public {
        // use a random address to make sure it doesn't work
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setExecutor(address(executor));
    }

    // test setting pool max capacity
    function testSetMaxCapacity() public {
        InsurancePool(pool1).setMaxCapacity(1000);
        assertEq(InsurancePool(pool1).maxCapacity() == 1000, true);
    }

    function testGetMaxCapacity() public {
        assertEq(InsurancePool(pool1).maxCapacity() == 1000 ether, true);
    }

    function testSetExecutorInsurancePool() public {
        InsurancePool(pool1).setExecutor(address(executor));
        assertEq(InsurancePool(pool1).executor() == address(executor), true);
    }

    function testSetIncidentReport() public {
        InsurancePool(pool1).setIncidentReport(address(incidentReport));
        assertEq(
            InsurancePool(pool1).incidentReport() == address(incidentReport),
            true
        );
    }
}
