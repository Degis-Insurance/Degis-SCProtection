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


contract InsurancePoolDeploymentAndRunTest is Test {

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
        vm.label(address(shield), "shield token");
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
    }

    function testGetPoolAddressListReinsurancePoolOnly() public {
        address[] memory list = ipf.getPoolAddressList();
        uint256 length = list.length;
        for (uint i = 0; length > i; i++){
            console.log(list[i]);
        }
        assertEq(list[0] == address(rp), true);
    }

    function testMintShield() public {
        shield.transfer(address(this), 10000);
        assertEq(shield.balanceOf(address(this)) == 10000 * (10**18), true);
    }

    function testDeployPool() public {
        pool1 = ipf.deployPool(
            "insurance",
            ptp,
            uint256(10000),
            uint256(1)
        );
        console.log("pool1 address");
        console.log(pool1);
        assertEq(ipf.getPoolCounter() == 1, true);
    }

    function testApprovePolicyCenter() public {
        shield.approve(address(policyc), 10000);
        assertEq(shield.allowance(address(this), address(policyc)) == 10000, true);
    }

    function testApprovePool() public {
        shield.approve(pool1, 10000);
        assertEq(shield.allowance(address(this), pool1) == 10000, true);
    }

}