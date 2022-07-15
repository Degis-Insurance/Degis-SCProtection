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


contract PreInsurancePoolDeploymentAndRunTest is Test {

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
        vm.expectRevert("amount exceeds maxCapacity");
       policyc.provideLiquidity(1, 10001);
    }

    function testRemoveLiquidityAfterTimeIP() public {
        policyc.provideLiquidity(1, 10000);
       assertEq(InsurancePool(pool1).balanceOf(address(this)) == 10000, true);
        vm.warp(604801);
        policyc.removeLiquidity(1, 10000);
        assertEq(shield.balanceOf(address(this)) == 10000 * 10**18, true);
    }

    function testGetCoveragePrice() public {
        uint256 price = InsurancePool(pool1).coveragePrice(10000, 365);
        assertEq(price == 10000 * 1 * 365 / uint256(1 days) * (1460 + 1 - 365) / 1460, true);
    }

    function testBuyCoverageWithoutSuppliedLiquidity() public {
        uint256 price = InsurancePool(pool1).coveragePrice(1000, 365);
        console.log(price);
        policyc.buyCoverage(1, price, 1000, 365);
        (uint256 amount, uint256 buyDate, uint256 length) = InsurancePool(pool1).getCoverage(address(this));

        assertEq(amount == 1000, true);
    }

    function testBuyCoverage() public {
        policyc.provideLiquidity(1, 10000);
        uint256 price = InsurancePool(pool1).coveragePrice(1000, 365);
        console.log(price);
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

    }
}

contract ProposalCenterTest is Test {

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
        rp.setDeg(address(deg));
        rp.setVeDeg(address(vedeg));
        rp.setShield(address(shield));
        rp.setPolicyCenter(address(policyc));
        rp.setProposalCenter(address(proposalc));
        rp.setPolicyCenter(address(policyc));
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
    }

    function testSetBufffers() public {
        proposalc.setBuffers(4 days, 4 days);
        assertEq(proposalc.reportBuffer() ==  4 days, true);
        assertEq(proposalc.proposalBuffer() ==  4 days, true);
    }
    
    function testProposePool() public {
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        (string memory protocolName,
        address protocolAddress,,,,,,,,,) = proposalc.getPoolProposal(1);
        console.log(protocolName);
        assertEq(protocolAddress == yeti, true);
    }

    function testReportPool() public {
        deg.transfer(address(this), 1000);
        deg.approve(address(proposalc), 1000e18);
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        proposalc.reportPool(1);
        
        (,,address reporterAddress,,, bool pending ,bool approved,) = proposalc.getReport(1);
        assertEq(reporterAddress == address(this), true);
        assertEq(pending == true, true);
        assertEq(approved == false, true);
    }

    function testSetPoolReportedByOwner() public {
        proposalc.setPoolReported(ptp, true);
        assertEq(proposalc.poolReported(ptp) == true, true);
    }

    function setProposal() public {
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        proposalc.setProposal(1, true);
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(2);
        assertEq( approved == true, true);
    }   
}

contract ProposalCenterVotingTest is Test {

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
        shield = new MockSHIELD(10000000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        policyc = new PolicyCenter(address(rp));
        e = new Executor();
        proposalc = new ProposalCenter();
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
        InsurancePool(pool1).setPolicyCenter(address(policyc));
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        InsurancePool(pool1).setInsurancePoolFactory(address(ipf));
        deg.transfer(address(this), 1000e18);
        deg.approve(address(proposalc), 10000e18);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 3000e18);
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        proposalc.reportPool(1);
    }

    function testVoteProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        (,,,address[] memory voted,,,,,,,) = proposalc.getPoolProposal(1);
        bool aliceVoted;
        bool bobVoted;
        bool carolVoted;
        for (uint i = 0; i < voted.length; i++){
            console.log(voted[i]);
            if (voted[i] == alice){
                aliceVoted = true;
            } else if (voted[i] == bob){
                bobVoted = true;
            } else if ( voted[i] == carol) {
               carolVoted = true;
            }
        }
        assertEq(aliceVoted == true, true);
        assertEq(bobVoted == true, true);
        assertEq(carolVoted == true, true);
    }

    function testVoteReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        (,,,,,,,address[] memory voted) = proposalc.getReport(1);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        assertEq(aliceVote == true, true);
        assertEq(bobVote == false, true);
        assertEq(carolVote == true, true);
    }

    function testVoteMoreThanOnceOnReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        proposalc.voteReport(1, true);
    }

    function testVoteMoreThanOnceOnPoolProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(alice);
        vm.expectRevert("Address already voted");
        proposalc.votePoolProposal(1, true);
    }

    function testEvaluateReportNotEnoughVotes() public {
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        (,,,,,,,address[] memory voted) = proposalc.getReport(1);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        vm.warp(604801);
        vm.prank(ptp);
        vm.expectRevert("Not enough votes");
        proposalc.evaluateReportVotes(1);
    }

    function testEvaluateReportTrue() public {
       vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        (,,,,,,,address[] memory voted) = proposalc.getReport(1);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        (,,,,,,bool approved,) = proposalc.getReport(1);
        assertEq(approved == true, true);
    }

    function testEvaluateReportFalse() public {
       vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, false);
        (,,,,,,,address[] memory voted) = proposalc.getReport(1);
        bool aliceVote;
        bool bobVote;
        bool carolVote;
        aliceVote = proposalc.confirmsReport(1,alice);
        bobVote = proposalc.confirmsReport(1,bob);
        carolVote = proposalc.confirmsReport(1,carol);
        vm.warp(604801);
        vm.prank(ptp);
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(1);
        assertEq(approved == false, true);
    }

    function testEvaluatePoolProposalTrue() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(1);
        assertEq(approved == true, true);
    }

    function testEvaluatePoolProposalFalse() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, false);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);    
        (,,,,,,,,,,bool approved) = proposalc.getPoolProposal(1);
        assertEq(approved == false, true); 
    }

    function testReportPoolAlreadyReported() public {
        deg.transfer(alice, 1000);
        vm.prank(alice);
        deg.approve(address(proposalc), 1000e18);
        vm.prank(alice);
        vm.expectRevert("Pool already reported");
        proposalc.reportPool(1);
    }

    function testProposePooolAlreadyProposed() public {
        vm.prank(alice);
        vm.expectRevert("Protocol already proposed");
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
    }

    function testReportPoolAfterFailedReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, false);
        vm.prank(bob);
        proposalc.voteReport(1, false);
        vm.prank(carol);
        proposalc.voteReport(1, false);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending1,bool approved1,) = proposalc.getReport(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        proposalc.reportPool(1);
        (,,,,,bool pending2,bool approved2,) = proposalc.getReport(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }

    function testProposePoolAfterFailedProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, false);
        vm.prank(bob);
        proposalc.votePoolProposal(1, false);
        vm.prank(carol);
        proposalc.votePoolProposal(1, false);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        (,,,,,,,,,bool pending1,bool approved1) = proposalc.getPoolProposal(1);
        assertEq(pending1 == false, true);
        assertEq(approved1 == false, true);
        (,,,,,,,,,bool pending2,bool approved2) = proposalc.getPoolProposal(2);
        assertEq(pending2 == true, true);
        assertEq(approved2 == false, true);
    }

    function testReportPoolAfterSuccessfulReport() public {
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, true);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluateReportVotes(1);
        (,,,,,bool pending,bool approved,) = proposalc.getReport(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
        vm.expectRevert("Pool already reported");
        proposalc.reportPool(1);
    }

    function testProposePoolAfterSuccessfulProposal() public {
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, true);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        vm.warp(604801);
        vm.prank(ptp);
        proposalc.evaluatePoolProposalVotes(1);
        (,,,,,,,,,bool pending,bool approved) = proposalc.getPoolProposal(1);
        assertEq(pending == false, true);
        assertEq(approved == true, true);
         vm.expectRevert("Protocol already proposed");
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
    } 
}

contract ExecutorTest is Test {

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
        shield = new MockSHIELD(10000000e18, "Shield", 18, "SHIELD");
        deg = new MockDEG(10000e18, "Degis", 18, "DEG");
        vedeg = new MockVeDEG(10000e18, "veDegis", 18, "veDeg");
        rp = new ReinsurancePool(address(shield));
        ipf = new InsurancePoolFactory(address(rp), address(shield));
        policyc = new PolicyCenter(address(rp));
        e = new Executor();
        proposalc = new ProposalCenter();
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
        InsurancePool(pool1).setPolicyCenter(address(policyc));
        InsurancePool(pool1).setProposalCenter(address(proposalc));
        InsurancePool(pool1).setInsurancePoolFactory(address(ipf));
        deg.transfer(address(this), 1000e18);
        deg.approve(address(proposalc), 10000e18);
        vedeg.transfer(alice, 3000e18);
        vedeg.transfer(bob, 2000e18);
        vedeg.transfer(carol, 3000e18);
        policyc.provideLiquidity(1, 1000e18);
        proposalc.proposePool(yeti, "Yeti", 10000, 1);
        proposalc.reportPool(1);
        vm.prank(alice);
        proposalc.votePoolProposal(1, true);
        vm.prank(bob);
        proposalc.votePoolProposal(1, true);
        vm.prank(carol);
        proposalc.votePoolProposal(1, true);
        vm.prank(alice);
        proposalc.voteReport(1, true);
        vm.prank(bob);
        proposalc.voteReport(1, true);
        vm.prank(carol);
        proposalc.voteReport(1, true);
        vm.warp(604801);
        vm.prank(address(0x1abc));
        proposalc.evaluatePoolProposalVotes(1);
        vm.prank(address(0x1abc));
        proposalc.evaluateReportVotes(1);
    }
}

contract LiquidationTest is Test {
    // function testClaimPayoutIP() public {
    //     policyc.claimPayout(1, 10000)
    // }
}

contract PostLiquidationTest is Test {

}