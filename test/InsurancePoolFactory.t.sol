// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/pools/InsurancePoolFactory.sol";
import "src/pools/ReinsurancePool.sol";
import "src/core/PolicyCenter.sol";
import "src/voting/ProposalCenter.sol";
import "src/mock/MockSHIELD.sol";

import "src/interfaces/IExecutor.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IPremiumVault.sol";
import "src/interfaces/IProposalCenter.sol";
import "src/interfaces/IComittee.sol";


// address insurancePool;
// address reinsurancePool;

contract InsurancePoolFactoryTest is Test {
    address constant insurancePoolFactory = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    InsurancePoolFactory ipf;
    ReinsurancePool rp;
    PolicyCenter policyc;
    ProposalCenter proposalc;
    MockSHIELD shield;

    function setUp() public {
        ipf = new InsurancePoolFactory();
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        rp = new ReinsurancePool(address(shield));
        policyc = new PolicyCenter(address(rp));
        proposalc = new ProposalCenter();
        ipf.setPolicyCenter(address(policyc));
        policyc.setInsurancePoolFactory(address(ipf));
    }

    function testPoolCounterInitialization() public {
        assertEq(ipf.poolCounter() == 0, true);
    }

    function testDeployPool() public {
        address pool1 = ipf.deployPool(
            "pool1",
            address(ipf),
            10000
        );
        assertEq(ipf.poolCounter() == 1, true);
    }
}
