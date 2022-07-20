// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ReinsurancePool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/ProposalCenter.sol";
import "src/mock/MockSHIELD.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/core/Executor.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/ReinsurancePoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IProposalCenter.sol";
import "src/interfaces/IComittee.sol";
import "src/interfaces/IExecutor.sol";

contract setAddressesTest is Test {

    InsurancePoolFactory public ipf;
    ReinsurancePool public rp;
    PolicyCenter public policyc;
    ProposalCenter public proposalc;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public e;

    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    address public ptp = address(0x133704);
    address public yeti = address(0x133705);
    address public pool1;

    function setUp() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        assertEq(keccak256(bytes(deg.name())) == keccak256(bytes("Degis")), true);
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        vm.label(address(vedeg), "veDegis token");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        vm.label(address(rp), "Reinsurance Pool");
        vm.label(address(ipf), "Insurance Pool Factory");
        policyc = new PolicyCenter(address(rp));
        vm.label(address(policyc), "Policy Center");
        e = new Executor();
        vm.label(address(e), "Executor");
        proposalc = new ProposalCenter();
        vm.label(address(proposalc), "Proposal Center");
    }

    function testSetPolicyCenterAddress() public {
        ipf.setPolicyCenter(address(policyc));
        console.log(ipf.policyCenter());
        assertEq(ipf.policyCenter() == address(policyc), true);
    }

    function testSetInsurancePoolFactoryAddress() public {
        policyc.setInsurancePoolFactory(address(ipf));
        console.log(policyc.insurancePoolFactory());
        assertEq(policyc.insurancePoolFactory() == address(ipf), true);
    }

    function testSetDEG() public {
        proposalc.setDeg(address(deg));
         assertEq(proposalc.deg() == address(deg), true);
    }

     function testSetVeDEG() public {
        proposalc.setVeDeg(address(vedeg));
        assertEq(proposalc.veDeg() == address(vedeg), true);
    }
     function testSetSHIELD() public {
        proposalc.setShield(address(shield));
        assertEq(proposalc.shield() == address(shield), true);
    }
     function testSetReinsurancePool() public {
        proposalc.setReinsurancePool(address(rp));
        assertEq(proposalc.reinsurancePool() == address(rp), true);
    }

    function testSetInsurancePoolFactory() public {
         proposalc.setInsurancePoolFactory(address(ipf));
         assertEq(proposalc.insurancePoolFactory() == address(ipf), true);
    }
    
     function testSetExecutor() public {
        proposalc.setExecutor(address(e));
        assertEq(proposalc.executor() == address(e), true);
    }

    function testSetPolicyCenterNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        ipf.setPolicyCenter(address(policyc));
    }

    function testSetDEGNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        proposalc.setDeg(address(deg));
    }

     function testSetVeDEGNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        proposalc.setVeDeg(address(vedeg));
    }
     function testSetSHIELDNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        proposalc.setShield(address(shield));
    }
     function testSetReinsurancePoolNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        proposalc.setReinsurancePool(address(rp));
    }

    function testSetInsurancePoolFactoryNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
         proposalc.setInsurancePoolFactory(address(ipf));
    }
    
     function testSetExecutorNotOwner() public {
        vm.prank(address(0x0000abcdef));
        vm.expectRevert("Ownable: caller is not the owner");
        proposalc.setExecutor(address(e));
    }
}