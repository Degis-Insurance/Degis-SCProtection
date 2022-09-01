// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./utils/ContractSetupBaseTest.sol";

import "src/interfaces/IPolicyCenter.sol";

import "src/core/interfaces/PolicyCenterEventError.sol";
import "src/pools/protectionPool/ProtectionPoolEventError.sol";
import "src/pools/priorityPool/PriorityPoolEventError.sol";
import "src/core/interfaces/PolicyCenterDependencies.sol";
import "src/voting/incidentReport/IncidentReportParameters.sol";
import "src/voting/onboardProposal/OnboardProposalParameters.sol";

contract PolicyCenterTest is
    PolicyCenterEventError,
    ProtectionPoolEventError,
    PriorityPoolEventError,
    OnboardProposalParameters,
    IncidentReportParameters,
    ContractSetupBaseTest
{
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    uint256 internal constant JOE_ID = 1;
    uint256 internal constant PTP_ID = 2;
    uint256 internal constant GMX_ID = 3;

    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant COVER_AMOUNT = 100e12;
    uint256 internal constant PAYOUT = 50;
    uint256 internal constant LIQUIDITY_UNIT = 100e6;
    uint256 internal constant MIN_COVER_AMOUNT = 100e6;

    uint256 internal constant ZERO_TIME = 0;
    uint256 internal constant LIQUIDITY = 1000 ether;

    uint256 internal constant VOTE_FOR = 1;
    uint256 internal constant VOTE_AGAINST = 2;
    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant PROPOSAL_VOTE_TIME = 0;
    uint256 internal constant INCIDENT_VOTE_TIME = PENDING_PERIOD;

    uint256 internal constant PROPOSAL_SETTLE_TIME =
        PROPOSAL_VOTE_TIME + PROPOSAL_VOTING_PERIOD;
    uint256 internal constant INCIDENT_SETTLE_TIME =
        INCIDENT_VOTE_TIME + INCIDENT_VOTING_PERIOD;

    IPriorityPool internal joePool;
    IPriorityPool internal ptpPool;
    IPriorityPool internal gmxPool;

    MockERC20 internal joe;
    MockERC20 internal ptp;
    MockERC20 internal gmx;
    MockERC20 internal usdc;

    address internal joeLPAddress;
    address internal ptpLPAddress;
    address internal gmxLPAddress;

    address internal crJoeAddress;
    address internal crPtpAddress;
    address internal crGmxAddress;

    event NewPayout(
        uint256 _poolId,
        uint256 _generation,
        uint256 _amount,
        uint256 _ratio
    );

    error PayoutPool__NotPolicyCenter();
    error PayoutPool__WrongCRToken();
    error PayoutPool__NoPayout();

    function setUp() public {
        setUpContracts();

        // Deploy usdc
        usdc = new MockERC20("USDC", "USDC", 18);

        // Set USDC address to current mainnet address
        bytes memory bytecode = address(usdc).code;
        vm.etch(policyCenter.USDC(), bytecode);

        vm.warp(ZERO_TIME);

        // Deploy three protocol tokens
        joe = new MockERC20("JoeToken", "JOE", 18);
        ptp = new MockERC20("PTPToken", "PTP", 18);
        gmx = new MockERC20("GMXToken", "GMX", 18);

        // Deploy three priority pools
        joePool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "TraderJoe",
                address(joe),
                CAPACITY_1,
                PREMIUMRATIO_1
            )
        );

        ptpPool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "Platypus",
                address(ptp),
                CAPACITY_2,
                PREMIUMRATIO_2
            )
        );

        gmxPool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "GMX",
                address(gmx),
                CAPACITY_3,
                PREMIUMRATIO_3
            )
        );

        joeLPAddress = joePool.currentLPAddress();
        ptpLPAddress = ptpPool.currentLPAddress();
        gmxLPAddress = gmxPool.currentLPAddress();

        // Mint veDEG for voters
        veDEG.mint(ALICE, 100 ether);
        veDEG.mint(BOB, 100 ether);

        // Fund exchange
        deg.mintDegis(address(exchange), 1000 ether);
        shield.mint(address(exchange), 1000 ether);
        MockERC20(policyCenter.USDC()).mint(address(exchange), 1000 ether);
        joe.mint(address(exchange), 1000 ether);
        ptp.mint(address(exchange), 1000 ether);
        gmx.mint(address(exchange), 1000 ether);
    }

    function testProvideLiquidity() public {
        // Approve shield expense to Policy Center
        vm.prank(CHARLIE);
        shield.approve(address(policyCenter), LIQUIDITY);
        // # --------------------------------------------------------------------//
        // # Should not be able to provide liquidity without shield # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.provideLiquidity(1);

        console.log(unicode"✅ Not provide liquidity without shield");

        // Mint shield to Charlie
        shield.mint(CHARLIE, LIQUIDITY);

        // # --------------------------------------------------------------------//
        // # Should not be able to provide 0 liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__ZeroAmount.selector);
        policyCenter.provideLiquidity(0);

        console.log(unicode"✅ Not provide liquidity offerring zero shield");

        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should not be able to provide liquidity directly to protection pool # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(ProtectionPool__OnlyPolicyCenter.selector);
        protectionPool.providedLiquidity(LIQUIDITY, CHARLIE);

        console.log(
            unicode"✅ Not provide liquidity directly to protection pool"
        );

        // Revert and take a new snapshot
        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(CHARLIE, LIQUIDITY);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity");

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity in different times # //
        // # --------------------------------------------------------------------//

        shield.mint(CHARLIE, LIQUIDITY);
        vm.prank(CHARLIE);
        shield.increaseAllowance(address(policyCenter), LIQUIDITY);
        vm.warp(365 days);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(CHARLIE, LIQUIDITY);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity after a year");

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity by multiple users # //
        // # --------------------------------------------------------------------//

        shield.mint(ALICE, LIQUIDITY);
        vm.prank(ALICE);
        shield.approve(address(policyCenter), LIQUIDITY);
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(ALICE, LIQUIDITY);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity by multiple users");

        // Revert and take a new snapshot
        vm.revertTo(snapshot_2);
        // mint tokens so Bob can report pool
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.prank(CHARLIE);
        // report any priority pool
        incidentReport.report(JOE_ID, PAYOUT);

        // # --------------------------------------------------------------------//
        // # Should not be able to provide liquidity during any incident report # //
        // # --------------------------------------------------------------------//

        shield.mint(CHARLIE, LIQUIDITY);
        vm.prank(CHARLIE);
        shield.increaseAllowance(address(policyCenter), LIQUIDITY);
        vm.prank(CHARLIE);
        // TODO: should be an error?
        // vm.expectRevert("Paused");
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(CHARLIE, LIQUIDITY);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(
            unicode"✅ Not provide liquidity while there is an incident report"
        );

        // vote and terminate incident report
        vm.warp(INCIDENT_VOTE_TIME);
        // Start voting incident report 1 (PTP incident)
        incidentReport.startVoting(1);

        // Take a new snapshot
        uint256 snapshot_3 = vm.snapshot();

        vm.prank(ALICE);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);
        vm.warp(INCIDENT_SETTLE_TIME);
        incidentReport.settle(1);

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity after a false report # //
        // # --------------------------------------------------------------------//

        shield.mint(CHARLIE, LIQUIDITY);
        vm.prank(CHARLIE);
        shield.increaseAllowance(address(policyCenter), LIQUIDITY);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(CHARLIE, LIQUIDITY);
        policyCenter.provideLiquidity(LIQUIDITY);

        console.log(unicode"✅ Provide liquidity after a false report");

        // Revert to snapshot
        vm.revertTo(snapshot_3);
        
        vm.prank(ALICE);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.warp(INCIDENT_SETTLE_TIME);
        incidentReport.settle(1);

        // # --------------------------------------------------------------------//
        // # Should be able to provide liquidity after a truthful report # //
        // # --------------------------------------------------------------------//

        shield.mint(CHARLIE, LIQUIDITY);
        vm.prank(CHARLIE);
        shield.increaseAllowance(address(policyCenter), LIQUIDITY);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(CHARLIE, LIQUIDITY);

        console.log(unicode"✅ Provide liquidity after a truthful report");
    }

    function _provideLiquidity(address _user) private {
        vm.warp(ZERO_TIME);
        shield.mint(_user, LIQUIDITY);
        vm.prank(_user);
        shield.approve(address(policyCenter), LIQUIDITY);
        vm.prank(_user);
        policyCenter.provideLiquidity(LIQUIDITY);
    }

    function testRemoveLiquidity() public {
        // # --------------------------------------------------------------------//
        // # Should not be able to remove liquidity without providing liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(ProtectionPool__ExceededTotalSupply.selector);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(
            unicode"✅ Not remove liquidity without providing liquidity"
        );

        // Charlie provides liquidity
        _provideLiquidity(CHARLIE);

        // # --------------------------------------------------------------------//
        // # Should not be able to remove other user's liquidity # //
        // # --------------------------------------------------------------------//

        // Alice attempts to remove liquidity provided by Charlie
        vm.prank(ALICE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Not remove other user's liquidity");

        // # --------------------------------------------------------------------//
        // # Should not be able to remove more then liquidity provided without supply # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(ProtectionPool__ExceededTotalSupply.selector);
        policyCenter.removeLiquidity(LIQUIDITY + 1);

        console.log(unicode"✅ Not remove more then liquidity provided");

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(CHARLIE, LIQUIDITY);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Remove liquidity");

        // Provide liquidity by Charlie again
        _provideLiquidity(CHARLIE);
        // Provide extra liquidity by Alice
        _provideLiquidity(ALICE);

        // # --------------------------------------------------------------------//
        // # Should not be able to remove more liquidity then provided with supply # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        policyCenter.removeLiquidity(LIQUIDITY * 2);

        console.log(unicode"✅ Not remove more liquidity then provided");

        // Provide liquidity by Charlie again
        _provideLiquidity(CHARLIE);

        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity after considrable time # //
        // # --------------------------------------------------------------------//

        vm.warp(365 days);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(CHARLIE, LIQUIDITY);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Remove liquidity after a year");

        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        // Provide liquidity twice by Charlie
        _provideLiquidity(CHARLIE);
        _provideLiquidity(CHARLIE);

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity provided in multiple instances # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(CHARLIE, LIQUIDITY * 2);
        policyCenter.removeLiquidity(LIQUIDITY * 2);

        console.log(unicode"✅ Remove liquidity provided in multiple instances");

        vm.revertTo(snapshot_2);

        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.prank(CHARLIE);
        // report any priority pool
        incidentReport.report(JOE_ID, PAYOUT);

        // # --------------------------------------------------------------------//
        // # Should not be able to remove liquidity during any incident report # //
        // # --------------------------------------------------------------------//

        _provideLiquidity(CHARLIE);

        vm.prank(CHARLIE);
        vm.expectRevert("Paused");  
        policyCenter.removeLiquidity(LIQUIDITY * 2);

        console.log(
            unicode"✅ Not remove liquidity during any incident report"
        );

        // vote and terminate incident report
        vm.warp(365 days + INCIDENT_VOTE_TIME);
        // Start voting incident report 1 (PTP incident)
        incidentReport.startVoting(2);

        // Take a new snapshot
        uint256 snapshot_3 = vm.snapshot();

        vm.prank(ALICE);
        incidentReport.vote(2, VOTE_AGAINST, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(2, VOTE_AGAINST, VOTE_AMOUNT);
        vm.warp(365 days + INCIDENT_SETTLE_TIME);
        incidentReport.settle(2);

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity after a false report # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(CHARLIE, LIQUIDITY);
        policyCenter.removeLiquidity(LIQUIDITY);

        console.log(unicode"✅ Remove liquidity after a false report");

        // Revert to snapshot
        vm.revertTo(snapshot_3);

        vm.prank(ALICE);
        incidentReport.vote(2, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(2, VOTE_FOR, VOTE_AMOUNT);
        vm.warp(365 days + INCIDENT_SETTLE_TIME);
        incidentReport.settle(2);

        // # --------------------------------------------------------------------//
        // # Should be able to remove liquidity after a truthful report # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit LiquidityProvided(LIQUIDITY, LIQUIDITY, CHARLIE);

        console.log(unicode"✅ Remove liquidity after a truthful report");
    }

    function testStake() public {
        vm.prank(ALICE);
        protectionPool.approve(address(policyCenter), LIQUIDITY);
        vm.prank(BOB);
        protectionPool.approve(address(policyCenter), LIQUIDITY);
        vm.prank(CHARLIE);
        protectionPool.approve(address(policyCenter), LIQUIDITY);

        // # --------------------------------------------------------------------//
        // # Should not be able to stake liquidity without providing liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        console.log(
            unicode"✅ Not stake liquidity without providing liquidity"
        );

        // Provide liquidity by multiple users
        _provideLiquidity(ALICE);
        _provideLiquidity(BOB);
        _provideLiquidity(CHARLIE);

        // staking requires a minimum amount of time passed since priority pool creation
        vm.warp(ZERO_TIME);

        // # --------------------------------------------------------------------//
        // # Should not be able to stake 0 liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__ZeroAmount.selector);
        policyCenter.stakeLiquidity(JOE_ID, 0);

        console.log(unicode"✅ Not stake 0 liquidity");

        // # --------------------------------------------------------------------//
        // # Should not be able to stake liquidity to inexistent Priority Pool # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__NonExistentPool.selector);
        policyCenter.stakeLiquidity(4, LIQUIDITY);

        console.log(
            unicode"✅ Not stake liquidity to inexistent Priority Pool"
        );

        // # --------------------------------------------------------------------//
        // # Should not be able to stake more then provided liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        protectionPool.increaseAllowance(address(policyCenter), LIQUIDITY * 2);
        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY * 2);

        console.log(unicode"✅ Not stake more then provided liquidity");

        // Snapshot before staking
        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should be able to stake provided liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        console.log(unicode"✅ Stake provided liquidity");

        // # --------------------------------------------------------------------//
        // # Should not be able to stake with same liquidity to multiple pools # //
        // # --------------------------------------------------------------------//

        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        emit StakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.stakeLiquidity(PTP_ID, LIQUIDITY);

        console.log(unicode"✅ Stake provided liquidity to multiple pools");

        // # --------------------------------------------------------------------//
        // # Should be able to stake to multiple priority pools # //
        // # --------------------------------------------------------------------//

        vm.revertTo(snapshot_2);
        uint256 snapshot_3 = vm.snapshot();

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY / 2, CHARLIE);
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY / 2);

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY / 2, CHARLIE);
        policyCenter.stakeLiquidity(PTP_ID, LIQUIDITY / 2);

        console.log(unicode"✅ Stake provided liquidity");

        // Revert and take a new snapshot
        vm.revertTo(snapshot_3);
        uint256 snapshot_4 = vm.snapshot();
        // mint tokens so Bob can report pool
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.prank(CHARLIE);
        // report unrelated priority pool
        incidentReport.report(JOE_ID, PAYOUT);

        // # --------------------------------------------------------------------//
        // # Should be able to stake to not reported  Pool during an incident # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.stakeLiquidity(PTP_ID, LIQUIDITY);

        console.log(
            unicode"✅ Stake to not reported Priority Pool during a report"
        );

        vm.revertTo(snapshot_4);
        // mint tokens so Bob can report pool
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.prank(CHARLIE);
        // report unrelated priority pool
        incidentReport.report(JOE_ID, PAYOUT);

        // # --------------------------------------------------------------------//
        // # Should not be able to stake during incident report # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("Paused");
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        console.log(unicode"✅ Not stake to reported Priority Pool");

        // # --------------------------------------------------------------------//
        // # Should be able to stake after incident settles # //
        // # --------------------------------------------------------------------//

        // Vote and settle
        vm.prank(ALICE);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.warp(INCIDENT_SETTLE_TIME + 1);
        incidentReport.settle(1);

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit StakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);

        console.log(
            unicode"✅ Stake to not reported Priority Pool during a report"
        );
    }

    function _stake(address _user) private {
        _provideLiquidity(_user);
        vm.warp(ZERO_TIME);
        vm.prank(_user);
        protectionPool.approve(address(policyCenter), LIQUIDITY);
        vm.prank(_user);
        policyCenter.stakeLiquidity(JOE_ID, LIQUIDITY);
    }

    function testUnstake() public {
        joeLPAddress = policyCenter.currentLPAddress(JOE_ID);

        // # --------------------------------------------------------------------//
        // # Should not be able to unstake liquidity without staking # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

        console.log(unicode"✅ Not unstake liquidity without staking");

        // Provide liquidity by multiple users
        _stake(ALICE);
        _stake(BOB);
        _stake(CHARLIE);

        // staking requires a minimum amount of time passed since priority pool creation
        vm.warp(ZERO_TIME);

        // # --------------------------------------------------------------------//
        // # Should not be able to unstake 0 # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__ZeroAmount.selector);
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, 0);

        console.log(unicode"✅ Not unstake 0");

        // # --------------------------------------------------------------------//
        // # Should not be able to unstake more then staked amount # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        protectionPool.increaseAllowance(address(policyCenter), LIQUIDITY * 2);
        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY * 2);

        console.log(unicode"✅ Not unstake less then staked amount");

        // # --------------------------------------------------------------------//
        // # Should be able to unstake less then staked amount # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit UnstakedLiquidity(LIQUIDITY / 2, CHARLIE);
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY / 2);

        console.log(unicode"✅ Unstake less then staked amount");

        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should be able to unstake staked amount # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit UnstakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

        console.log(unicode"✅ Unstake staked amount");


        vm.prank(CHARLIE);
        // mint tokens so Charlie can report pool
        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
        vm.prank(CHARLIE);
        // report unrelated priority pool
        incidentReport.report(JOE_ID, PAYOUT);

        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should not be able to unstake liquidity during incident report # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("Paused");
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

        console.log(unicode"✅ Not unstake liquidity during incident report");

        // # --------------------------------------------------------------------//
        // # Should be able to unstake liquidity to unrelated incident report # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit UnstakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

        vm.revertTo(snapshot_2);
        uint256 snapshot_3 = vm.snapshot();

        console.log(
            unicode"✅ Unstake liquidity during unrelated incident report"
        );

        // # --------------------------------------------------------------------//
        // # Should be able to unstake after truthful incident report # //
        // # --------------------------------------------------------------------//

        vm.warp(INCIDENT_VOTE_TIME);
        // Vote and settle
        vm.prank(ALICE);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.warp(INCIDENT_SETTLE_TIME);
        incidentReport.settle(1);

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit UnstakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

        console.log(
            unicode"✅ Unstake liquidity after truthful incident report"
        );

        vm.revertTo(snapshot_3);

        // # --------------------------------------------------------------------//
        // # Should be able to unstake after false incident report # //
        // # --------------------------------------------------------------------//

        vm.warp(INCIDENT_VOTE_TIME);
        // Vote and settle
        vm.prank(ALICE);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(1, VOTE_AGAINST, VOTE_AMOUNT);
        vm.warp(INCIDENT_SETTLE_TIME);
        incidentReport.settle(1);

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit UnstakedLiquidity(LIQUIDITY, CHARLIE);
        policyCenter.unstakeLiquidity(JOE_ID, joeLPAddress, LIQUIDITY);

        console.log(unicode"✅ Unstake liquidity after false incident report");
    }

    function testBuyCover() public {
        // get Cover Price for a given amount of tokens
        (uint256 price, uint256 coverLength) = joePool.coverPrice(
            COVER_AMOUNT,
            3
        );

        uint256 maxPayment = price * 11 / 10;

        // approve JOE
        vm.prank(CHARLIE);
        joe.approve(address(policyCenter), type(uint256).max);
        MockERC20(policyCenter.USDC()).approve(address(policyCenter), type(uint256).max);

        // # --------------------------------------------------------------------//
        // # Should not be able to buy cover without provided liquidity # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        shield.approve(address(policyCenter), type(uint256).max);

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__InsufficientCapacity.selector);
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        console.log(unicode"✅ Not buy cover without provided liquidity");

        // Provide liquidity and increase max capacity
        _provideLiquidity(CHARLIE);

        // # --------------------------------------------------------------------//
        // # Should not be able to buy cover without native tokens # //
        // # --------------------------------------------------------------------//

        // buy with shield
        shield.mint(CHARLIE, COVER_AMOUNT);

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        // buy with other pool's native tokens
        gmx.mint(BOB, COVER_AMOUNT);

        vm.prank(CHARLIE);
        gmx.approve(address(policyCenter), type(uint256).max);

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        console.log(unicode"✅ Not buy cover without native token");


        joe.mint(CHARLIE, COVER_AMOUNT);
        // # --------------------------------------------------------------------//
        // # Should not be able to buy 0 cover # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__CoverAmountTooSmall.selector);
        policyCenter.buyCover(JOE_ID, 0, 3, 0);

        console.log(unicode"✅ Not buy 0 cover");

        // # --------------------------------------------------------------------//
        // # Should not be able to buy without enough tokens # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT + 1, 3, maxPayment + 1);

        console.log(unicode"✅ Not buy without enough tokens");

        // # --------------------------------------------------------------------//
        // # Should not be able to buy bad length covers # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__BadLength.selector);
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 4, maxPayment);

        console.log(unicode"✅ Not buy bad length covers");

        // # --------------------------------------------------------------------//
        // # Should not be able to buy below cover min # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__CoverAmountTooSmall.selector);
        policyCenter.buyCover(JOE_ID, MIN_COVER_AMOUNT - 1, 3, maxPayment);

        console.log(unicode"✅ Not buy below cover min");

        // # --------------------------------------------------------------------//
        // # Should not be able to buy with low max payment # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__PremiumTooHigh.selector);
        policyCenter.buyCover(JOE_ID, MIN_COVER_AMOUNT, 3, maxPayment / 2);

        console.log(unicode"✅ Not buy low max payment");

        // # --------------------------------------------------------------------//
        // # Should be able to buy cover # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit CoverBought(CHARLIE, JOE_ID, 3, COVER_AMOUNT, price);
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        console.log(unicode"✅ Buy cover");

        deg.mintDegis(ALICE, REPORT_THRESHOLD);
        vm.prank(ALICE);
        incidentReport.report(JOE_ID, PAYOUT);

        uint256 snapshot_1 = vm.snapshot();

        // # --------------------------------------------------------------------//
        // # Should not be able to buy during incident report # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert("Paused");
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        console.log(unicode"✅ Not buy cover during incident report");

        // # --------------------------------------------------------------------//
        // # Should be able to buy after truthful incident report # //
        // # --------------------------------------------------------------------//

        vm.prank(ALICE);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(BOB);
        incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);

        deg.mintDegis(ALICE, REPORT_THRESHOLD);
        vm.prank(ALICE);
        incidentReport.report(JOE_ID, PAYOUT);

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__BadLength.selector);
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        console.log(unicode"✅ Buy cover after truthful incident report");

        // # --------------------------------------------------------------------//
        // # Should be able to buy after false incident report # //
        // # --------------------------------------------------------------------//

        vm.revertTo(snapshot_1);

        deg.mintDegis(ALICE, REPORT_THRESHOLD);
        vm.prank(ALICE);
        incidentReport.report(JOE_ID, PAYOUT);

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__BadLength.selector);
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);

        console.log(unicode"✅ Buy cover after false incident report");
    }

    function _buyJoeCover(address _user) internal {
        (uint256 price, uint256 length) = joePool.coverPrice(COVER_AMOUNT, 3);
        uint256 maxPayment = price * 11 / 10;
        vm.prank(_user);
        joe.approve(address(policyCenter), type(uint256).max);
        joe.mint(_user, COVER_AMOUNT);
        vm.prank(_user);
        policyCenter.buyCover(JOE_ID, COVER_AMOUNT, 3, maxPayment);
    }

    function testClaimPayout() public {
        _provideLiquidity(CHARLIE);
        _buyJoeCover(CHARLIE);

        MockERC20(policyCenter.USDC()).approve(address(policyCenter), type(uint256).max);

        deg.mintDegis(CHARLIE, REPORT_THRESHOLD);

        vm.prank(CHARLIE);
        incidentReport.report(1, PAYOUT);
        vm.warp(INCIDENT_VOTE_TIME);
        vm.prank(ALICE);
        incidentReport.vote(2, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(ALICE);
        incidentReport.vote(2, VOTE_FOR, VOTE_AMOUNT);
        vm.warp(INCIDENT_SETTLE_TIME);
        incidentReport.settle(2);

        // # --------------------------------------------------------------------//
        // # Should not be to claim payout prior to liquidation # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PayoutPool__NoPayout.selector);
        policyCenter.claimPayout(JOE_ID, crJoeAddress, 1);

        console.log(unicode"✅ Not claim payout prior to liquidation");

        // # --------------------------------------------------------------------//
        // # Should not be to claim with wrong cover right address # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PayoutPool__WrongCRToken.selector);
        policyCenter.claimPayout(JOE_ID, crJoeAddress, 1);

        console.log(unicode"✅ Not claim with wrong address");

        // # --------------------------------------------------------------------//
        // # Should not be to claim wrong pool id # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__NonExistentPool.selector);
        policyCenter.claimPayout(JOE_ID, crJoeAddress, 1);

        console.log(unicode"✅ Not claim with wrong pool id");

        // # --------------------------------------------------------------------//
        // # Should not be to claim wrong generation # //
        // # --------------------------------------------------------------------//

        vm.prank(CHARLIE);
        vm.expectRevert(PolicyCenter__NonExistentPool.selector);
        policyCenter.claimPayout(JOE_ID, crJoeAddress, 1);

        console.log(unicode"✅ Not claim with non existent generation");

        // # --------------------------------------------------------------------//
        // # Should be able to claim payout # //
        // # --------------------------------------------------------------------//

        uint256 snapshot_1 = vm.snapshot();

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit PayoutClaimed(CHARLIE, COVER_AMOUNT);
        policyCenter.claimPayout(JOE_ID, crJoeAddress, 1);

        console.log(unicode"✅ Claim from current generation");

        // # --------------------------------------------------------------------//
        // # Should be able to claim payout from previous generation # //
        // # --------------------------------------------------------------------//

        // Revert to snapshot
        vm.revertTo(snapshot_1);

        uint256 timestamp = block.timestamp;

        veDEG.mint(ALICE, 100 ether);
        veDEG.mint(BOB, 100 ether);

        // Report Joe Pool once again
        incidentReport.report(1, PAYOUT);
        vm.warp(INCIDENT_VOTE_TIME);
        vm.prank(ALICE);
        incidentReport.vote(2, VOTE_FOR, VOTE_AMOUNT);
        vm.prank(ALICE);
        incidentReport.vote(2, VOTE_FOR, VOTE_AMOUNT);
        vm.warp(timestamp + INCIDENT_SETTLE_TIME);
        incidentReport.settle(2);

        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit PayoutClaimed(CHARLIE, COVER_AMOUNT);
        policyCenter.claimPayout(JOE_ID, crJoeAddress, 1);

        console.log(unicode"✅ Claim Payout from previous generation");
    }
}
