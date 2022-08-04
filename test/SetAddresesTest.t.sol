// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ReinsurancePool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/OnboardProposal.sol";
import "src/voting/IncidentReport.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";
import "src/mock/MockExchange.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/ReinsurancePoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IExecutor.sol";

contract setAddressesTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
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
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor = new Executor();
        incidentReport = new IncidentReport();
        onboardProposal = new OnboardProposal();
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));

        pool1 = insurancePoolFactory.deployPool("Platypus", address(ptp), 1000 ether, 260);
    }

    function testSetPolicyCenterAddress() public {
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        console.log(insurancePoolFactory.policyCenter());
        assertEq(insurancePoolFactory.policyCenter() == address(policyCenter), true);
    }

    function testSetInsurancePoolFactoryAddress() public {
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        console.log(policyCenter.insurancePoolFactory());
        assertEq(policyCenter.insurancePoolFactory() == address(insurancePoolFactory), true);
    }

    function testSetDEG() public {
        onboardProposal.setDeg(address(deg));
         assertEq(onboardProposal.deg() == address(deg), true);
    }

     function testSetVeDEG() public {
        onboardProposal.setVeDeg(address(vedeg));
        assertEq(onboardProposal.veDeg() == address(vedeg), true);
    }
     function testSetSHIELD() public {
        onboardProposal.setShield(address(shield));
        assertEq(onboardProposal.shield() == address(shield), true);
    }
     function testSetReinsurancePool() public {
        onboardProposal.setReinsurancePool(address(reinsurancePool));
        assertEq(onboardProposal.reinsurancePool() == address(reinsurancePool), true);
    }

    function testSetInsurancePoolFactory() public {
         onboardProposal.setInsurancePoolFactory(address(insurancePoolFactory));
         assertEq(onboardProposal.insurancePoolFactory() == address(insurancePoolFactory), true);
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

    function testSetDEGNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setDeg(address(deg));
    }

     function testSetVeDEGNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setVeDeg(address(vedeg));
    }
     function testSetSHIELDNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setShield(address(shield));
    }
     function testSetReinsurancePoolNotOwner() public {
        // use a non owner address to make sure it's not allowed to set address
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.setReinsurancePool(address(reinsurancePool));
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

    // since insurance pools are deployed from the insurance pool factory,
    // it has a administrator role initially set during deployment.
    function testSetInsurancePoolAdministrator() public {
        InsurancePool(pool1).setAdministrator(alice);
        assertEq(InsurancePool(pool1).administrator() == alice, true);
        vm.prank(alice);
        InsurancePool(pool1).setAdministrator(bob);
        assertEq(InsurancePool(pool1).administrator() == address(bob), true);
    }

    function testSetPoolFactoryAdministratorNotOwner() public {
        insurancePoolFactory.setAdministrator(alice);
        assertEq(insurancePoolFactory.administrator() == alice, true);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        insurancePoolFactory.setAdministrator(bob);
    }

    // test setting pool max capacity
    function testSetMaxCapacity() public {
        InsurancePool(pool1).setMaxCapacity(1000);
        assertEq(InsurancePool(pool1).maxCapacity() == 1000, true);
    }

    function testGetMaxCapacity() public {
        assertEq(InsurancePool(pool1).maxCapacity() == 1000 ether, true);
    }

    function testSetDEGInsurancePool() public {
        InsurancePool(pool1).setDeg(address(deg));
        assertEq(InsurancePool(pool1).deg() == address(deg), true);
    }

     function testSetVeDEGInsurancePool() public {
        InsurancePool(pool1).setVeDeg(address(vedeg));
        assertEq(InsurancePool(pool1).veDeg() == address(vedeg), true);
    }
     function testSetSHIELDInsurancePool() public {
        InsurancePool(pool1).setShield(address(shield));
        assertEq(InsurancePool(pool1).shield() == address(shield), true);
    }
     function testSetReinsurancePoolInsurancePool() public {
        InsurancePool(pool1).setReinsurancePool(address(reinsurancePool));
        assertEq(InsurancePool(pool1).reinsurancePool() == address(reinsurancePool), true);
    }

    function testSetInsurancePoolFactoryInsurancePool() public {
          InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
         assertEq(InsurancePool(pool1).insurancePoolFactory() == address(insurancePoolFactory), true);
    }
    
     function testSetExecutorInsurancePool() public {
         InsurancePool(pool1).setExecutor(address(executor));
        assertEq(InsurancePool(pool1).executor() == address(executor), true);
    }

    function testSetIncidentReport() public {
        InsurancePool(pool1).setIncidentReport(address(incidentReport));
        assertEq(InsurancePool(pool1).incidentReport() == address(incidentReport), true);
    }
}