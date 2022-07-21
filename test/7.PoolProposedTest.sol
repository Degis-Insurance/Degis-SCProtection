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

contract ClaimPayoutTest is Test {

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
    address public pool2;

    function setUp() public {
        shield = new MockSHIELD(10000000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        policyc = new PolicyCenter(address(rp));
        e = new Executor();
        proposalc = new ProposalCenter();
        deg.addMinter(address(proposalc));
        vm.label(address(proposalc), "Proposal Center");
        ipf.setDeg(address(deg));
        ipf.setVeDeg(address(vedeg));
        ipf.setShield(address(shield));
        ipf.setPolicyCenter(address(policyc));
        ipf.setProposalCenter(address(proposalc));
        ipf.setReinsurancePool(address(rp));
        ipf.setPolicyCenter(address(policyc));
        rp.setDeg(address(deg));
        rp.setVeDeg(address(vedeg));
        rp.setShield(address(shield));
        rp.setPolicyCenter(address(policyc));
        rp.setProposalCenter(address(proposalc));
        rp.setPolicyCenter(address(policyc));
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
        pool1 = ipf.deployPool("insurance", ptp, uint256(10000), uint256(1));
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setExecutor(address(e));
        InsurancePool(pool1).setPolicyCenter(address(policyc));
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        InsurancePool(pool1).setInsurancePoolFactory(address(ipf));
        deg.transfer(address(this), 1000e18);
        deg.transfer(address(proposalc), 1000e18);
        deg.approve(address(proposalc), 10000e18);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 3000e18);
        shield.transfer(address(this), 1000e18);
        shield.approve(address(policyc), 10000e18);
        policyc.provideLiquidity(1, 10000);
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        vm.warp(350000);
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, true);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        vm.warp(500000);
        vm.prank(address(0x1abc));
        proposalc.evaluatePoolProposalVotes(1);
        vm.warp(590000);
        proposalc.evaluatePoolProposalVotes(1);
        vm.warp(1000000);
        pool2 = e.executeNewPool(1);
        InsurancePool(pool2).setDeg(address(deg));
        InsurancePool(pool2).setVeDeg(address(vedeg));
        InsurancePool(pool2).setShield(address(shield));
        InsurancePool(pool2).setExecutor(address(e));
        InsurancePool(pool2).setPolicyCenter(address(policyc));
        InsurancePool(pool2).setProposalCenter(address(proposalc));
        InsurancePool(pool2).setInsurancePoolFactory(address(ipf));
    }

    function testPresenceNewPool() public {
        string memory name = InsurancePool(pool2).name();
        uint256 maxCapacity = InsurancePool(pool2).maxCapacity();
        console.log(name);
        assertEq(maxCapacity == 10000, true);
    }

    function testProvideLiquidityNewPool() public {
        policyc.provideLiquidity(2, 10000);
        assertEq(InsurancePool(pool2).totalSupply() == 10000, true);
    }

    function testBuyCoverageNewPool() public {
        uint256 price  = InsurancePool(pool2).coveragePrice(10000, 100);
        policyc.buyCoverage(2, price, 10000, 100);
        (uint256 amount,,) = policyc.getCoverage(2, address(this));
        assertEq(amount == 10000, true);
    }
}