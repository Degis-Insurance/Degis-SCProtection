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

contract ClaimPayoutTest is Test {

    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    Exchange public exchange;
    Executor public executor;
    ERC20 public ptp;
    ERC20 public yeti;

    // defines users
    address public alice = address(0x1337);
    address public bob = address(0x133702);
    address public carol = address(0x133703);
    // pool1 address
    address public pool1;
    address public pool2;

    function setUp() public {
        shield = new MockSHIELD(10000000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        yeti = new ERC20Mock("Yeti","YETI", address(this), 10000e18);
        reinsurancePool = new ReinsurancePool();
        insurancePoolFactory = new InsurancePoolFactory(address(reinsurancePool), address(deg));
        policyCenter = new PolicyCenter(address(reinsurancePool), address(deg));
        executor =new Executor();
        proposalCenter = new ProposalCenter();
        // deploy exchange and supply tokens can be swapped during buy coverage split
        exchange = new Exchange();
        deg.transfer(address(exchange), 1000e18);
        shield.transfer(address(exchange), 1000e18);
        ptp.transfer(address(exchange), 1000e18);
        deg.addMinter(address(proposalCenter));
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setProposalCenter(address(proposalCenter));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setExecutor(address(executor));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setProposalCenter(address(proposalCenter));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setExecutor(address(executor));
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setProposalCenter(address(proposalCenter));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        proposalCenter.setDeg(address(deg));
        proposalCenter.setVeDeg(address(vedeg));
        proposalCenter.setShield(address(shield));
        proposalCenter.setExecutor(address(executor));
        proposalCenter.setPolicyCenter(address(policyCenter));
        proposalCenter.setReinsurancePool(address(reinsurancePool));
        proposalCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        executor.setDeg(address(deg));
        executor.setVeDeg(address(vedeg));
        executor.setShield(address(shield));
        executor.setPolicyCenter(address(policyCenter));
        executor.setProposalCenter(address(proposalCenter));
        executor.setReinsurancePool(address(reinsurancePool));
        executor.setInsurancePoolFactory(address(insurancePoolFactory));
        pool1 = insurancePoolFactory.deployPool("Platypus", address(ptp), uint256(10000), uint256(1));
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setExecutor(address(executor));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
        deg.transfer(address(this), 1000e18);
        deg.transfer(address(proposalCenter), 1000e18);
        deg.approve(address(proposalCenter), 10000e18);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 3000e18);
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        proposalCenter.proposePool(address(yeti), "Yeti", 10000, 1);
        vm.warp(350000);
        vm.prank(alice);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(bob);
        proposalCenter.votePoolProposal(1, true);
        vm.prank(carol);
        proposalCenter.votePoolProposal(1, true);
        vm.warp(500000);
        vm.prank(address(0x1abc));
        proposalCenter.evaluatePoolProposalVotes(1);
        vm.warp(590000);
        proposalCenter.evaluatePoolProposalVotes(1);
        vm.warp(1000000);
        pool2 =executor.executeNewPool(1);
        InsurancePool(pool2).setDeg(address(deg));
        InsurancePool(pool2).setVeDeg(address(vedeg));
        InsurancePool(pool2).setShield(address(shield));
        InsurancePool(pool2).setExecutor(address(executor));
        InsurancePool(pool2).setPolicyCenter(address(policyCenter));
        InsurancePool(pool2).setProposalCenter(address(proposalCenter));
        InsurancePool(pool2).setInsurancePoolFactory(address(insurancePoolFactory));
    }

    function testPresenceNewPool() public {
        string memory name = InsurancePool(pool2).name();
        uint256 maxCapacity = InsurancePool(pool2).maxCapacity();
        console.log(name);
        assertEq(maxCapacity == 10000, true);
    }

    function testProvideLiquidityNewPool() public {
        yeti.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(2, 10000);
        assertEq(InsurancePool(pool2).totalSupply() == 10000, true);
    }

    function testBuyCoverageNewPool() public {
        yeti.approve(address(policyCenter), 10000e18);
        uint256 price  = InsurancePool(pool2).coveragePrice(10000, 90);
        policyCenter.buyCoverage(2, price, 10000, 90);
        (uint256 amount,,) = policyCenter.getCoverage(2, address(this));
        assertEq(amount == 10000, true);
    }
    
    function testSetAdministratorProposedPool() public {
        InsurancePool(pool1).setAdministrator(alice);
        assertEq(InsurancePool(pool1).administrator() == address(alice), true);
        vm.prank(alice);
        InsurancePool(pool1).setAdministrator(bob);
        assertEq(InsurancePool(pool1).administrator() == address(bob), true);
    }

    function testWrongSetAdministrator() public {
        vm.prank(alice);
        vm.expectRevert("Only owner, executor or administrator can call this function");
        InsurancePool(pool1).setAdministrator(alice);
    }

    function claimRewardsReinsurancePoolMultiplePools() public {

    }
}