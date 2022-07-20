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

contract PolicyCenterTest is Test {

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
        shield.transfer(address(this), 10000);
        shield.approve(address(policyc), 10000e18);
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        policyc = new PolicyCenter(address(rp));
        e = new Executor();
        proposalc = new ProposalCenter();
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
        rp.setDeg(address(deg));
        rp.setVeDeg(address(vedeg));
        rp.setShield(address(shield));
        rp.setPolicyCenter(address(policyc));
        rp.setProposalCenter(address(proposalc));
        rp.setPolicyCenter(address(policyc));
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
        InsurancePool(pool1).setPolicyCenter(address(policyc));
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        InsurancePool(pool1).setReinsurancePool(address(rp));
        InsurancePool(pool1).setInsurancePoolFactory(address(ipf));
        shield.approve(address(policyc), 20000);
    }

    function testSetMaxCapacity() public {
        InsurancePool(pool1).setMaxCapacity(1000);
        assertEq(InsurancePool(pool1).maxCapacity() == 1000, true);
    }

    function testGetMaxCapacity() public {
        assertEq(InsurancePool(pool1).maxCapacity() == 10000, true);
    }

    function testGetPoolAddressListNewInsurancePool() public {
        address[] memory list = ipf.getPoolAddressList();
        uint256 length = list.length;
        for (uint i = 0; length > i; i++){
            
            console.log(list[i]);
        }
        console.log(address(rp));
        console.log(ptp);
        assertEq(list[0] == address(rp), true);
        assertEq(list[1] == pool1, true);
    }

    function testSetDEGIP() public {
        InsurancePool(pool1).setDeg(address(deg));
        assertEq(InsurancePool(pool1).deg() == address(deg), true);
    }

     function testSetVeDEGIP() public {
        InsurancePool(pool1).setVeDeg(address(vedeg));
        assertEq(InsurancePool(pool1).veDeg() == address(vedeg), true);
    }
     function testSetSHIELDIP() public {
        InsurancePool(pool1).setShield(address(shield));
        assertEq(InsurancePool(pool1).shield() == address(shield), true);
    }
     function testSetReinsurancePoolIP() public {
        InsurancePool(pool1).setReinsurancePool(address(rp));
        assertEq(InsurancePool(pool1).reinsurancePool() == address(rp), true);
    }

    function testSetInsurancePoolFactoryIP() public {
          InsurancePool(pool1).setInsurancePoolFactory(address(ipf));
         assertEq(InsurancePool(pool1).insurancePoolFactory() == address(ipf), true);
    }
    
     function testSetExecutorIP() public {
         InsurancePool(pool1).setExecutor(address(e));
        assertEq(InsurancePool(pool1).executor() == address(e), true);
    }

    function testProvideLiquidityIP() public {
        policyc.provideLiquidity(1, 10000);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityBeforeTimeIP() public {
        policyc.provideLiquidity(1, 10000);
        vm.expectRevert("cannot remove liquidity within 7 days of last claim");
        policyc.removeLiquidity(1, 10000);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
         assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
    }

    function testExceedMaxCapacity() public {
        InsurancePool(pool1).setMaxCapacity(10);
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 365);
        vm.expectRevert("exceeds max capacity");
        policyc.buyCoverage(1,price, 10000 , 365);
    }

    function provideLiqudityDirectlyToInsurancePool() public {
        vm.expectRevert("cannot provide liquidity directly to insurance pool");
        InsurancePool(pool1).provideLiquidity(10000, address(this));
    }

    function removeLiquidityDirectlyFromInsurancePool() public {
        policyc.provideLiquidity(1, 10000);
        vm.expectRevert("cannot remove liquidity directly from insurance pool");
        InsurancePool(pool1).removeLiquidity(10000, address(this));
    }

    function testRemoveLiquidityAfterTimeIP() public {
        policyc.provideLiquidity(1, 10000);
        assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        vm.warp(604801);
        policyc.removeLiquidity(1, 10000);
    }

    function testGetCoveragePrice() public {
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 365);
        assertEq(price == 10000 * 1 * 365 / uint256(1 days) * (1460 + 1 - 365) / 1460, true);
    }

    function testBuyCoverageWithoutSuppliedLiquidity() public {
        uint256 price = InsurancePool(pool1).coveragePrice(1000, 365);
        console.log(price);
        policyc.buyCoverage(1, price, 1000, 365);
        (uint256 amount,,) = InsurancePool(pool1).getCoverage(address(this));
        assertEq(amount == 1000, true);
    }

    function testBuyCoverage() public {
        policyc.provideLiquidity(1, 10000);
        uint256 price = InsurancePool(pool1).coveragePrice(1000, 365);
        shield.approve(address(policyc), 100e18);
        policyc.buyCoverage(1, price, 1000, 365);
        (uint256 amount, uint256 buyDate, uint256 length) = InsurancePool(pool1).getCoverage(address(this));
        assertEq(amount == 1000, true);
        assertEq(buyDate - block.timestamp < 100, true);
        assertEq(length == 365, true);
    }

    function testBuyWrongPaymentCoverage() public{
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 365);
        price--;
        vm.expectRevert("pay does not correspond to price");
        policyc.buyCoverage(1, price, 10000, 365);
    }

    function testProvideLiquidityRP() public {
        policyc.provideLiquidity(0, 10000);
        assertEq(ReinsurancePool(rp).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityBeforeTimeRP() public {
        policyc.provideLiquidity(0, 10000);
        vm.expectRevert("cannot remove liquidity within 7 days of last claim");
        policyc.removeLiquidity(0, 10000);
        assertEq(ReinsurancePool(rp).balanceOf(address(this)) == 10000, true);
         assertEq(ReinsurancePool(rp).balanceOf(address(this)) == 10000, true);
    }

    function testRemoveLiquidityAfterTimeRP() public {
        policyc.provideLiquidity(0, 10000);
       assertEq(ReinsurancePool(rp).balanceOf(address(this)) == 10000, true);
        vm.warp(604801);
        policyc.removeLiquidity(0, 10000);
        assertEq(shield.balanceOf(address(this)) == 10000 * 10**18, true);
    }

    function testSetPremiumSplit() public {
        policyc.setPremiumSplit(999, 1999, 7000);
        (uint256 split0, uint256 split1,  uint256 split2) = policyc.getPremiumSplits();
        assertEq(split0 == 999, true);
        assertEq(split1 == 1999, true);
        assertEq(split2 == 7000, true);
    }

    function testSplitPremium() public {
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 365);
        policyc.buyCoverage(1, price, 10000, 365);
        console.log(shield.balanceOf(address(policyc)));
        policyc.splitPremium(1);
    }

    function testRemoveLiquidityAfterReport() public {
        policyc.provideLiquidity(1, 10000);
        assertEq(ReinsurancePool(rp).balanceOf(address(this)) == 10000, true);
        deg.transfer(address(this), 1000);
        deg.approve(address(proposalc), 10000e18);
        vm.warp(1000000);
        proposalc.reportPool(1);
        vm.expectRevert("cannot remove liquidity while paused");
        policyc.removeLiquidity(1, 10000);
    }
}