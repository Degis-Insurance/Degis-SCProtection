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
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
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
        assertEq(e.poolBuffer() == 3 days, true);
    }

    function testDeployProposalCenter() public {
        proposalc = new ProposalCenter();
        vm.label(address(proposalc), "Proposal Center");

        assertEq(address(proposalc) == address(0), false);
    }
}