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
import "src/mock/MockExchange.sol";

import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/ReinsurancePoolErrors.sol";
import "src/interfaces/IPolicyCenter.sol";
import "src/interfaces/IReinsurancePool.sol";
import "src/interfaces/IInsurancePool.sol";
import "src/interfaces/IProposalCenter.sol";
import "src/interfaces/IComittee.sol";
import "src/interfaces/IExecutor.sol";

import "forge-std/console.sol";


/**
@notice Tests user Interactions from user side.
        Initial
*/
contract PostInsurancePoolDeploymentTest is Test {
    InsurancePoolFactory public insurancePoolFactory;
    ReinsurancePool public reinsurancePool;
    PolicyCenter public policyCenter;
    ProposalCenter public proposalCenter;
    MockSHIELD public shield;
    MockDEG public deg;
    MockVeDEG public vedeg;
    InsurancePool public insurancePool;
    // added exchange for mock swapping tokens
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

        function setUp() public {
        // deploys tokens
        shield = new MockSHIELD(10000e18, "Shield", 18, "SHIELD");
        shield.approve(address(policyCenter), 20000);
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        deg.transfer(address(this), 100e18);
        ptp = new ERC20Mock("Platypus", "PTP", address(this), 10000e18);
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        vedeg.transfer(address(this), 100e18);
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

        // sets addresses needed to execute functions
        insurancePoolFactory.setDeg(address(deg));
        insurancePoolFactory.setVeDeg(address(vedeg));
        insurancePoolFactory.setShield(address(shield));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        insurancePoolFactory.setProposalCenter(address(proposalCenter));
        insurancePoolFactory.setReinsurancePool(address(reinsurancePool));
        insurancePoolFactory.setPolicyCenter(address(policyCenter));
        policyCenter.setDeg(address(deg));
        policyCenter.setVeDeg(address(vedeg));
        policyCenter.setShield(address(shield));
        policyCenter.setExecutor(address(executor));
        policyCenter.setProposalCenter(address(proposalCenter));
        policyCenter.setReinsurancePool(address(reinsurancePool));
        policyCenter.setInsurancePoolFactory(address(insurancePoolFactory));
        policyCenter.setExchange(address(exchange));
        proposalCenter.setDeg(address(deg));
        reinsurancePool.setDeg(address(deg));
        reinsurancePool.setVeDeg(address(vedeg));
        reinsurancePool.setShield(address(shield));
        reinsurancePool.setPolicyCenter(address(policyCenter));
        reinsurancePool.setProposalCenter(address(proposalCenter));
        reinsurancePool.setPolicyCenter(address(policyCenter));
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
        // deploy ptp pool
        pool1 = insurancePoolFactory.deployPool("PTP", address(ptp), uint256(10000), uint256(1));
        // set addreses for ptp pool
        InsurancePool(pool1).setDeg(address(deg));
        InsurancePool(pool1).setVeDeg(address(vedeg));
        InsurancePool(pool1).setShield(address(shield));
        InsurancePool(pool1).setPolicyCenter(address(policyCenter));
        InsurancePool(pool1).setProposalCenter(address(proposalCenter));
        InsurancePool(pool1).setReinsurancePool(address(reinsurancePool));
        InsurancePool(pool1).setInsurancePoolFactory(address(insurancePoolFactory));
        
    }

    function testGetPoolAddressList() public {
        // reads list of pools in the protocol
        address[] memory list = insurancePoolFactory.getPoolAddressList();
        uint256 length = list.length;
        for (uint i = 0; length > i; i++){
            console.log(list[i]);
        }
        // asserts that the list is not empty
        assertEq(list[0] == address(reinsurancePool), true);
        assertEq(list[1] == pool1, true);
    }

    // test approve transfer of tokens to policy center
    // it will handle all transfers from protocol to users and vice versa
    function testApproveDegPolicyCenter() public {
        deg.approve(address(policyCenter), 10000e18);
        assertEq(deg.allowance(address(this), address(policyCenter)) == 10000e18, true);
    }

    function testApprovePTPPolicyCenter() public {
        // approve ptp pool to policy center
        ptp.approve(address(policyCenter), 10000e18);
        assertEq(ptp.allowance(address(this), address(policyCenter)) == 10000e18, true);
    }

    function testTransferVeDEGPolicyCenter() public {
        vm.prank(alice);
        vedeg.approve(address(policyCenter), 10000e18);
        assertEq(vedeg.allowance(alice, address(policyCenter)) == 10000e18, true);
        // user should not be able to transfer vedeg
        vm.prank(alice);
        vm.expectRevert("not whitelisted address");
        vedeg.transfer(address(policyCenter), 10000e18);
    }

    function testProvideLiquidityInsurancePool() public {
        // user should be able to provide liquidity to ptp pool in ptp
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        console.log(InsurancePool(pool1).totalSupply());
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        
    }

    function testRemoveLiquidityBeforeBufferTimeEndsnsurancePool() public {
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        vm.expectRevert("cannot remove liquidity within 7 days of last claim");
        policyCenter.removeLiquidity(1, 10000);
        // user should not be able to remove liquidity and liquidities should remain the same.
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityAfterBufferTimeEndsInsurancePool() public {
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        // change block timestamp to after buffer time
        vm.warp(604801);
        console.log(InsurancePool(pool1).totalSupply());
        policyCenter.removeLiquidity(1, 10000);
    }

    function testExceedMaxCapacity() public {
        ptp.approve(address(policyCenter), 10000e18);
        InsurancePool(pool1).setMaxCapacity(1);
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 90);
        // test should revert and emit message
        vm.expectRevert("exceeds max capacity");
        policyCenter.buyCoverage(1, price, 10000 , 90);
    }
    
    function testProvideLiqudityDirectlyToInsurancePool() public {
        ptp.approve(address(policyCenter), 10000e18);
        // user should not be able to provide liquidity directly to insurance pool
        vm.expectRevert("cannot provide liquidity directly to insurance pool");
        InsurancePool(pool1).provideLiquidity(10000, address(this));
    }

    function testRemoveLiquidityDirectlyFromInsurancePool() public {
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        vm.warp(604801);
        // user should not be able to provide liquidity directly to insurance pool
        vm.expectRevert("cannot remove liquidity directly from insurance pool");
        InsurancePool(pool1).removeLiquidity(10000, address(this));
    }

    function testRemoveLiquidityWithoutProvidingLiquidity() public {
        // user should not be able to remove liquidity without providing liquidity
        vm.expectRevert("Amount must be less than provided liquidity");
        policyCenter.removeLiquidity(1, 1);
    }

    
    function testGetCoveragePrice() public {
        // get coverage price and returns it
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 90);
        assertEq(price == 10000 * 1 * 90 / uint256(1 days) * (1460 + 1 - 90) / 1460, true);
    }

    function testBuyCoverageWithoutSuppliedLiquidity() public {
        // expected behavior when coverage is bought and no liquidity has been provided
        ptp.approve(address(policyCenter), 10000e18);
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 90);
        console.log(price);
        policyCenter.buyCoverage(1, price, 10000, 90);
        (uint256 amount,uint256 buyDate, uint256 length) = policyCenter.getCoverage(1, address(this));
        assertEq(amount == 10000, true);
        assertEq(buyDate - block.timestamp < 604810, true);
        assertEq(length == 90, true);
    }

    function testBuyCoverageWithSuppliedLiquidity() public {
        // expected behavior when coverage is bough with liquidity provided by other users
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 90);
        shield.approve(address(policyCenter), 100e18);
        policyCenter.buyCoverage(1, price, 10000, 90);
        (uint256 amount, uint256 buyDate, uint256 length) = policyCenter.getCoverage(1, address(this));
        assertEq(amount == 10000, true);
        assertEq(buyDate - block.timestamp < 604810, true);
        assertEq(length == 90, true);
    }

    function testBuyWrongPaymentCoverage() public{
        ptp.approve(address(policyCenter), 10000e18);
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 90);
        price--;
        // user should no be able to buy a coverage with wrong payment amount
        vm.expectRevert("pay does not correspond to price");
        policyCenter.buyCoverage(1, price, 10000, 90);
    }

    function testProvideLiquidityReinsurancePool() public {
        // user should be able to provide liquidity to reinsurance pool
        deg.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(0, 10000);
        assertEq(ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityBeforeBufferTimeReinsurancePool() public {
        deg.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(0, 10000);
        // user should not be able to remove liquidity from reinsurance pool prior to buffer time
        vm.expectRevert("cannot remove liquidity within 7 days of last claim");
        policyCenter.removeLiquidity(0, 10000);
        assertEq(ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000, true);
        assertEq(ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityAfterBufferTimeReinsurancePool() public {
        // user should be able to remove liquidity from reinsurance pool after buffer time
        deg.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(0, 10000);
        uint256 initialBalance = ptp.balanceOf(address(this));
        assertEq(ReinsurancePool(reinsurancePool).balanceOf(address(this)) == 10000, true);
        vm.warp(604801);
        policyCenter.removeLiquidity(0, 10000);
        assertEq(ptp.balanceOf(address(this)) == initialBalance, true);
    }

    function testSetPremiumSplit() public {
        // owner should be able to change premium split, up to 1000 bps
        policyCenter.setPremiumSplit(2000, 7000);
        (uint256 split1,  uint256 split2) = policyCenter.getPremiumSplits();
        assertEq(split1 == 2000, true);
        assertEq(split2 == 7000, true);
    }

    function testSetPremiumSplitBadInput() public {
        vm.expectRevert("Invalid split");
        // sum > 100%
        policyCenter.setPremiumSplit(3001, 7000);
    }

    function testFundsAreSplit() public {
        // test if funds end up being split properly among treasury, insurance pool and reinsurance pool
        ptp.approve(address(policyCenter), 10000e18);
        uint256 prevBalance = ptp.balanceOf(address(policyCenter));
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 90);
        policyCenter.buyCoverage(1, price, 10000, 90);
        console.log(ptp.balanceOf(address(policyCenter)));
        // assert that funds are split correctly, ptp balance is 45% of price
        assertEq(ptp.balanceOf(address(policyCenter)) == prevBalance + price * 45 / 100, true);
    }

    function testRemoveLiquidityAfterReport() public {
        // user should not be able to remove liquidity if pool has been reported
        ptp.approve(address(policyCenter), 10000e18);
        policyCenter.provideLiquidity(1, 10000);
        deg.transfer(address(this), 1000);
        deg.approve(address(proposalCenter), 10000e18);
        vm.warp(1000000);
        proposalCenter.reportPool(1);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        vm.expectRevert("cannot remove liquidity while paused");
        policyCenter.removeLiquidity(1, 10000);
    }

    function testClaimRewardsFromLiquidityProvisionNoRewards() public {
        // claim rewards for liquidity provision in a non liquidated pool
        // no coverage bought, therefore no rewards are available
        vm.prank(alice);
        ptp.approve(address(policyCenter), 20000e18);
        vm.prank(alice);
        policyCenter.provideLiquidity(1, 1000);
        vm.prank(bob);
        ptp.approve(address(policyCenter), 20000e18);
        vm.prank(bob);
        policyCenter.provideLiquidity(1, 1000);
        vm.prank(carol);
        ptp.approve(address(policyCenter), 1000e18);
        vm.prank(carol);
        policyCenter.provideLiquidity(1, 1000);
        vm.warp(30 days);
        vm.prank(alice);
        uint256 reward = policyCenter.calculateReward(1, alice);
        console.log("reward", reward);
        // no user should be able to claim rewards
        vm.prank(alice);
        vm.expectRevert("no rewards to claim");
        policyCenter.claimReward(1);
        vm.prank(bob);
        vm.expectRevert("no rewards to claim");
        policyCenter.claimReward(1);
        vm.prank(carol);
        vm.expectRevert("no rewards to claim");
        policyCenter.claimReward(1);
    }
}
