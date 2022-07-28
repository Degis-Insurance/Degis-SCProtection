// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
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

/** 
@notice Tests initial deployment for most contracts.
 */
contract InitialContractDeploymentTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public executor;

    function setUp() public {}

    function testDeployShield() public {
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        assertEq(keccak256(bytes(shield.name())) == keccak256(bytes("Shield")), true);
    }

    function testDeployDEG() public {
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        assertEq(keccak256(bytes(deg.name())) == keccak256(bytes("Degis")), true);
    }

    function testDeployVeDEG() public {
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        assertEq(keccak256(bytes(vedeg.name())) == keccak256(bytes("veDegis")), true);
    }

    function testDeployReinsurancePool() public {
        reinsurancePool = new ReinsurancePool();
        assertEq(keccak256(bytes(reinsurancePool.name())) == keccak256(bytes("ReinsurancePool")), true);
    }

    function testDeployExecutor() public {
       executor =new Executor();
        assertEq(executor.poolBuffer() == 1 days, true);
    }

    function testDeployProposalCenter() public {
        proposalCenter = new ProposalCenter();
        assertEq(address(proposalCenter) == address(0), false);
    }

    
}

/** 
@notice Tests secondary deployment for most contracts since they are dependent on other contracts.
 */
contract SecondaryContractDeploymentTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Executor public executor;
    ERC20 public ptp;

    function setUp() public {
        // Policy Center, Factory and Insurrance Pool require deg, a third party token
        // and the reinsurancePool already deployed.
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        reinsurancePool = new ReinsurancePool();
    }

    function testDeployPolicyCenter() public {
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        assertEq(policyCenter.reinsurancePool() == address(reinsurancePool), true);
    }

    function testDeployFactory() public {
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        assertEq(insurancePoolFactory.poolCounter() == 0, true);
    }

    function testDeployInsurancePool() public {
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        address pool1 = insurancePoolFactory.deployPool("PTP", address(ptp), 10000, 1);
        console.log(pool1);
    }
}