// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/PriorityPoolFactory.sol";
import "src/pools/ProtectionPool.sol";
import "src/core/PolicyCenter.sol";
import "src/pools/PayoutPool.sol";

import "src/voting/onboardProposal/OnboardProposal.sol";
import "src/voting/incidentReport/IncidentReport.sol";
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
    PriorityPoolFactory public priorityPoolFactory;
    ProtectionPool public protectionPool;
    PolicyCenter public policyCenter;
    PayoutPool public payoutPool;
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
        priorityPoolFactory = new PriorityPoolFactory(
            address(deg),
            address(vedeg),
            address(shield),
            address(protectionPool),
            address(payoutPool)
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
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setExchange(address(exchange));
        // required to provide liquidity
        protectionPool.setPolicyCenter(address(policyCenter));
        // pools require initial liquidity input to Protection pool
        policyCenter.provideLiquidity(10000 ether);

        pool1 = priorityPoolFactory.deployPool(
            "Platypus",
            address(ptp),
            1000 ether,
            260
        );
    }

    function testSetPolicyCenterAddress() public {
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        console.log(priorityPoolFactory.policyCenter());
        assertEq(
            priorityPoolFactory.policyCenter() == address(policyCenter),
            true
        );
    }

    function testSetPriorityPoolFactoryAddress() public {
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        console.log(policyCenter.priorityPoolFactory());
        assertEq(
            policyCenter.priorityPoolFactory() == address(priorityPoolFactory),
            true
        );
    }

    function testSetPriorityPoolFactory() public {
        onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));
        assertEq(
            onboardProposal.priorityPoolFactory() ==
                address(priorityPoolFactory),
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
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
    }

    function testSetPriorityPoolFactoryNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));
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
