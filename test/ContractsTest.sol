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


contract ContractDeploymentTest is Test {

    InsurancePoolFactory ipf;
    ReinsurancePool rp;
    PolicyCenter policyc;
    ProposalCenter proposalc;
    MockSHIELD shield;
    MockDEG deg;
    MockVeDEG vedeg;
    InsurancePool insurancePool;
    Executor e;

    function setUp() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        rp = new ReinsurancePool(address(shield));
    }

    function testDeployIpf() public {
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        vm.label(address(ipf), "Insurance Pool Factory");
        assertEq(ipf.poolCounter() == 0, true);
    }

    function testDeployShield() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        vm.label(address(shield), "shield token");
        assertEq(keccak256(bytes(shield.name())) == keccak256(bytes("Shield")), true);
    }

    function testDeployDEG() public {
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        vm.label(address(deg), "degis token");
        assertEq(keccak256(bytes(deg.name())) == keccak256(bytes("Degis")), true);
    }

    function testDeployVeDEG() public {
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDEG");
        vm.label(address(vedeg), "veDegis token");
        assertEq(keccak256(bytes(vedeg.name())) == keccak256(bytes("veDegis")), true);
    }

    function testDeployReinsurancePool() public {
        rp = new ReinsurancePool(address(shield));
        vm.label(address(rp), "Reinsurance Pool");
        assertEq(rp.shield() == address(shield), true);
    }

    function testDeployPolicyCenter() public {
        policyc = new PolicyCenter(address(rp));
        vm.label(address(policyc), "Policy Center");
        assertEq(policyc.reinsurancePool() == address(rp), true);
    }

    function testDeployExecutor() public {
        e = new Executor();
        vm.label(address(e), "Executor");
        assertEq(e.poolBuffer() == 7 days, true);
    }

    function testDeployProposalCenter() public {
        proposalc = new ProposalCenter();
        vm.label(address(proposalc), "Proposal Center");

        assertEq(address(proposalc) == address(0), false);
    }
}

contract setAddressesTest is Test {

    InsurancePoolFactory ipf;
    ReinsurancePool rp;
    PolicyCenter policyc;
    ProposalCenter proposalc;
    MockSHIELD shield;
    MockDEG deg;
    MockVeDEG vedeg;
    InsurancePool insurancePool;
    Executor e;

    function setUp() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        assertEq(keccak256(bytes(deg.name())) == keccak256(bytes("Degis")), true);
        vm.label(address(shield), "shield token");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDEG");
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
    }

     function testSetVeDEG() public {
        proposalc.setVeDeg(address(vedeg));
    }
     function testSetSHIELD() public {
        proposalc.setShield(address(shield));
    }
     function testSetReinsurancePool() public {
        proposalc.setReinsurancePool(address(rp));
    }

    function testSetInsurancePoolFactory() public {
         proposalc.setInsurancePoolFactory(address(ipf));
    }
    
     function testSetExecutor() public {
        proposalc.setExecutor(address(e));
    }
}


contract InsurancePoolDeploymentAndRunTest is Test {

    InsurancePoolFactory ipf;
    ReinsurancePool rp;
    PolicyCenter policyc;
    ProposalCenter proposalc;
    MockSHIELD shield;
    MockDEG deg;
    MockVeDEG vedeg;
    InsurancePool insurancePool;
    Executor e;

    address alice = address(0x1337);
    address bob = address(0x133702);
    address ptp = address(0x133703);

    address pool1;

function setUp() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        assertEq(keccak256(bytes(deg.name())) == keccak256(bytes("Degis")), true);
        vm.label(address(shield), "shield token");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDEG");
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
        ipf.setDeg(address(deg));
        ipf.setVeDeg(address(vedeg));
        ipf.setShield(address(shield));
        ipf.setPolicyCenter(address(policyc));
        ipf.setProposalCenter(address(proposalc));
        ipf.setReinsurancePool(address(rp));
        ipf.setPolicyCenter(address(policyc));
        policyc.setDeg(address(deg));
        policyc.setVeDeg(address(vedeg));
        policyc.setShield(address(shield));
        policyc.setExecutor(address(e));
        policyc.setProposalCenter(address(proposalc));
        policyc.setReinsurancePool(address(rp));
        policyc.setInsurancePoolFactory(address(ipf));
        proposalc.setDeg(address(deg));
        proposalc.setVeDeg(address(vedeg));
        proposalc.setShield(address(shield));
        proposalc.setExecutor(address(e));
        proposalc.setPolicyCenter(address(policyc));
        proposalc.setReinsurancePool(address(rp));
        proposalc.setInsurancePoolFactory(address(ipf));
        e.setDeg(address(deg));
        e.setVeDeg(address(vedeg));
        e.setShield(address(shield));
        e.setPolicyCenter(address(policyc));
        e.setProposalCenter(address(proposalc));
        e.setReinsurancePool(address(rp));
        e.setInsurancePoolFactory(address(ipf));
        
    }

function testDeployPool() public {
        pool1 = ipf.deployPool(
            "insurance",
            address(ptp),
            uint256(10000)
        );
        console.log("pool1 address");
        console.log(pool1);
        assertEq(ipf.getPoolCounter() == 1, true);
    }

    function testSetMaxCapacity() public {
        pool1 = ipf.deployPool(
            "insurance",
            address(ptp),
            uint256(10000)
        );
        InsurancePool(pool1).setMaxCapacity(1000);
        assertEq(InsurancePool(pool1).maxCapacity() == 1000, true);
    }

    function testGetPoolAddressListReinsurancePoolOnly() public {
        address[] memory list = ipf.getPoolAddressList();
        uint256 length = list.length;
        for (uint i = 0; length > i; i++){
            console.log(list[i]);
        }
        assertEq(list[0] == address(rp), true);
    }
}


contract ProposalCenterTest is Test {
    InsurancePoolFactory ipf;
    ReinsurancePool rp;
    PolicyCenter policyc;
    ProposalCenter proposalc;
    MockSHIELD shield;
    MockDEG deg;
    MockVeDEG vedeg;
    InsurancePool insurancePool;
    Executor e;

    address alice = address(0x1337);
    address bob = address(0x133702);
    address ptp = address(0x133703);
    address yeti = address(0x133704);

    address pool1;

function setUp() public {
       
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        assertEq(keccak256(bytes(deg.name())) == keccak256(bytes("Degis")), true);
        vm.label(address(shield), "shield token");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDEG");
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
        ipf.setDeg(address(deg));
        ipf.setVeDeg(address(vedeg));
        ipf.setShield(address(shield));
        ipf.setPolicyCenter(address(policyc));
        ipf.setProposalCenter(address(proposalc));
        ipf.setReinsurancePool(address(rp));
        ipf.setPolicyCenter(address(policyc));
        policyc.setDeg(address(deg));
        policyc.setVeDeg(address(vedeg));
        policyc.setShield(address(shield));
        policyc.setExecutor(address(e));
        policyc.setProposalCenter(address(proposalc));
        policyc.setReinsurancePool(address(rp));
        policyc.setInsurancePoolFactory(address(ipf));
        proposalc.setDeg(address(deg));
        proposalc.setVeDeg(address(vedeg));
        proposalc.setShield(address(shield));
        proposalc.setExecutor(address(e));
        proposalc.setPolicyCenter(address(policyc));
        proposalc.setReinsurancePool(address(rp));
        proposalc.setInsurancePoolFactory(address(ipf));
        e.setDeg(address(deg));
        e.setVeDeg(address(vedeg));
        e.setShield(address(shield));
        e.setPolicyCenter(address(policyc));
        e.setProposalCenter(address(proposalc));
        e.setReinsurancePool(address(rp));
        e.setInsurancePoolFactory(address(ipf));
    }
    // suggest pool
    function testProposePool() public {
        proposalc.proposePool(yeti, "Yeti", 10000);
    }
}