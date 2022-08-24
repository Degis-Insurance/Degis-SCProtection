// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./utils/ContractSetupTest.sol";

import "src/interfaces/IOnboardProposal.sol";

import "src/voting/onboardProposal/OnboardProposalParameters.sol";
import "src/voting/onboardProposal/OnboardProposalEventError.sol";

contract ProposalTest is
    ContractSetupBaseTest,
    OnboardProposalParameters,
    OnboardProposalEventError
{
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant PAYOUT = 1000e6;

    uint256 internal constant VOTE_FOR = 1;
    uint256 internal constant VOTE_AGAINST = 2;
    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant PROPOSE_TIME = 0;
    uint256 internal constant VOTE_TIME = 1;
    uint256 internal constant SETTLE_TIME = VOTE_TIME + PROPOSAL_VOTING_PERIOD;

    MockERC20 internal vtx;
    MockERC20 internal cra;
    MockERC20 internal stg;

    function setUp() public {
        // Set up contracts
        setUpContracts();

        // Deploy three protocol tokens
        vtx = new MockERC20("Vector", "VTX", 18);
        cra = new MockERC20("Crabada", "CRA", 18);
        stg = new MockERC20("StarGate", "STG", 18);
    }

    function testPropose() public {

        // # --------------------------------------------------------------------//
        // # Should not start a proposal without enough DEG balance # //
        // # --------------------------------------------------------------------//

        vm.warp(PROPOSE_TIME);
        vm.prank(CHARLIE);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        onboardProposal.propose(
            "Vector",
            address(vtx),
            CAPACITY_1,
            PREMIUMRATIO_1
        );

        console.log(
            unicode"✅ Not start a proposal without enough DEG balance"
        );

        // mint required degis to start a proposal
        deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);

        // # --------------------------------------------------------------------//
        // # Should not start a proposal if 0 capacity is suggested # //
        // # --------------------------------------------------------------------//

        vm.warp(PROPOSE_TIME);
        vm.prank(CHARLIE);
        vm.expectRevert(OnboardProposal__WrongCapacity.selector);
        onboardProposal.propose("Vector", address(vtx), 0, PREMIUMRATIO_1);

        console.log(unicode"✅ Not start a proposal with 0 capacity proposed");

        // # --------------------------------------------------------------------//
        // # Should not start a proposal if no premium ratio is suggested # //
        // # --------------------------------------------------------------------//

        vm.warp(PROPOSE_TIME);
        vm.prank(CHARLIE);
        vm.expectRevert(OnboardProposal__WrongPremium.selector);
        onboardProposal.propose("Vector", address(vtx), CAPACITY_1, 0);

        // # --------------------------------------------------------------------//
        // # Should not start a proposal if premium ratio suggested is over limit # //
        // # --------------------------------------------------------------------//

        vm.warp(PROPOSE_TIME);
        vm.prank(CHARLIE);
        vm.expectRevert(OnboardProposal__WrongPremium.selector);
        onboardProposal.propose("Vector", address(vtx), CAPACITY_1, 10001);

        console.log(
            unicode"✅ Not start a proposal if premium ratio suggested is over limit"
        );

        // # --------------------------------------------------------------------//
        // # Should be able to start a proposal with enough DEG # //
        // # --------------------------------------------------------------------//

        vm.warp(PROPOSE_TIME);
        vm.prank(CHARLIE);
        vm.expectEmit(false, false, false, true);
        emit NewProposal(
            "Vector",
            address(vtx),
            CHARLIE,
            CAPACITY_1,
            PREMIUMRATIO_1
        );
        onboardProposal.propose(
            "Vector",
            address(vtx),
            CAPACITY_1,
            PREMIUMRATIO_1
        );

        console.log(unicode"✅ Start a proposal with enough DEG");

        // # --------------------------------------------------------------------//
        // # Check the new proposal record # //
        // # --------------------------------------------------------------------//

        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.name, "Vector");
        assertEq(proposal.protocolToken, address(vtx));
        assertEq(proposal.proposer, CHARLIE);
        assertEq(proposal.proposeTimestamp, 0);
        assertEq(proposal.maxCapacity, CAPACITY_1);
        assertEq(proposal.status, PENDING_STATUS);
        assertEq(proposal.result, 0);

        // # --------------------------------------------------------------------//
        // # Check the DEG balance after starting the proposal
        assertEq(deg.balanceOf(CHARLIE), 0);

        // # --------------------------------------------------------------------//
        // # Check the proposal counter after starting the proposal
        assertEq(onboardProposal.proposalCounter(), 1);

        console.log(unicode"✅ Check new proposal record");

        // # --------------------------------------------------------------------//
        // # Should not be able to start a proposal already proposed # //
        // # --------------------------------------------------------------------//

        deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
        vm.warp(PROPOSE_TIME);
        vm.prank(CHARLIE);
        vm.expectRevert(OnboardProposal__AlreadyProposed.selector);
        onboardProposal.propose(
            "Vector",
            address(vtx),
            CAPACITY_1,
            PREMIUMRATIO_1
        );

        console.log(unicode"✅ Not start a proposal already proposed");
    }

    function _proposeVTX() internal {
        deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
        vm.warp(VOTE_TIME);
        vm.prank(CHARLIE);
        onboardProposal.propose(
            "Vector",
            address(vtx),
            CAPACITY_1,
            PREMIUMRATIO_1
        );
    }

    function testMultipleProposals() public {
        // Start a proposal
        _proposeVTX();

        // # --------------------------------------------------------------------//
        // # Should be able to start multiple proposal # //
        // # --------------------------------------------------------------------//

        assertEq(onboardProposal.proposalCounter(), 1);

        deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
        vm.warp(VOTE_TIME);
        vm.prank(CHARLIE);
        onboardProposal.propose(
            "Crabada",
            address(cra),
            CAPACITY_2,
            PREMIUMRATIO_2
        );
        assertEq(onboardProposal.proposalCounter(), 2);

        deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
        vm.warp(VOTE_TIME);
        vm.prank(CHARLIE);
        onboardProposal.propose(
            "Stargate",
            address(stg),
            CAPACITY_3,
            PREMIUMRATIO_3
        );
        assertEq(onboardProposal.proposalCounter(), 3);

        console.log(unicode"✅ Start multiple proposals");
    }

    function testcloseProposal() public {
        _proposeVTX();
        assertEq(onboardProposal.proposalCounter(), 1);

        // # --------------------------------------------------------------------//
        // # Should not be able to close a proposal by non-owner # //
        // # --------------------------------------------------------------------//

        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        onboardProposal.closeProposal(1);

        console.log(unicode"✅ Not close proposal by non-owner");

        // # --------------------------------------------------------------------//
        // # Should be able to close a proposal by the owner # //
        // # --------------------------------------------------------------------//

        vm.warp(VOTE_TIME - 1);
        vm.expectEmit(false, false, false, true);
        emit ProposalClosed(1, VOTE_TIME - 1);
        onboardProposal.closeProposal(1);

        console.log(unicode"✅ Close proposal by owner");

        // # --------------------------------------------------------------------//
        // # Check the closed proposal record # //
        // # --------------------------------------------------------------------//

        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status, CLOSE_STATUS);

        console.log(unicode"✅ Check closed proposal record");

        // # --------------------------------------------------------------------//
        // # Start a new proposal on the same protocol # //
        // # --------------------------------------------------------------------//
        _proposeVTX();

        assertEq(onboardProposal.proposalCounter(), 2);

        console.log(unicode"✅ Start proposal on the same protocol");
    }

    function testStartVoting() public {
        // Start a proposal
        _proposeVTX();

        // # --------------------------------------------------------------------//
        // # Should be able to start a voting after proposal is made # //
        // # --------------------------------------------------------------------//
        
        vm.warp(VOTE_TIME);
        onboardProposal.startVoting(1);

        console.log(unicode"✅ Start a voting after proposal is made");


        // # --------------------------------------------------------------------//
        // # Should be able to check the record # //
        // # --------------------------------------------------------------------//
        
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status, VOTING_STATUS);
        assertEq(proposal.voteTimestamp, VOTE_TIME);

        console.log(unicode"✅ Check the record");

        // # --------------------------------------------------------------------//
        // # Should not be able to close a proposal with wrong status # //
        // # --------------------------------------------------------------------//
        
        vm.warp(VOTE_TIME);
        vm.expectRevert(OnboardProposal__WrongStatus.selector);
        onboardProposal.closeProposal(1);

        console.log(unicode"✅ Close a proposal with wrong status");

        // # --------------------------------------------------------------------//
        // # Should not be able to start a voting with VOTING_STATUS # //
        // # --------------------------------------------------------------------//
        
        vm.expectRevert(OnboardProposal__WrongStatus.selector);
        onboardProposal.startVoting(1);

        console.log(unicode"✅ Start a voting with VOTING_STATUS");

        // # --------------------------------------------------------------------//
        // # Should not be able to close a proposal after starting the vote # //
        // # --------------------------------------------------------------------//
        
        vm.warp(VOTE_TIME);
        vm.expectRevert(OnboardProposal__WrongStatus.selector);
        onboardProposal.closeProposal(1);

        console.log(unicode"✅ Close a proposal after starting the vote");

    }

    function _startVoting() internal {
        vm.warp(VOTE_TIME);
        onboardProposal.startVoting(1);
    }

    function testVote() public {
        // Start a proposal and start voting       
        _proposeVTX();
        _startVoting();


        // Start prank 
        vm.startPrank(ALICE);

        // ---------------------------------------------------------- //
        // * Should not be able to vote for without veDEG * //
        // ---------------------------------------------------------- //

        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(OnboardProposal__NotEnoughVeDEG.selector);
        onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);

        console.log(unicode"✅ Not vote for without veDEG");


        // ---------------------------------------------------------- //
        // * Should not be able to vote against without veDEG * //
        // ---------------------------------------------------------- //

        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(OnboardProposal__NotEnoughVeDEG.selector);
        onboardProposal.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        console.log(unicode"✅ Not able to vote against without veDEG");

        // ---------------------------------------------------------- //
        // * Should not be able to vote with a wrong choice * //
        // ---------------------------------------------------------- //

        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(OnboardProposal__WrongChoice.selector);
        onboardProposal.vote(1, 3, VOTE_AMOUNT);

        console.log(unicode"✅ Not able to vote with a wrong choice");

        // ---------------------------------------------------------- //
        // * Should not be able to vote with zero amount * //
        // ---------------------------------------------------------- //

        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(OnboardProposal__ZeroAmount.selector);
        onboardProposal.vote(1, VOTE_FOR, 0);

        console.log(unicode"✅ Not able to vote with zero amount");

        // ---------------------------------------------------------- //
        // * Should be able to vote with veDEG * //
        // ---------------------------------------------------------- //

        veDEG.mint(ALICE, VOTE_AMOUNT);
        vm.warp(VOTE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ProposalVoted(1, ALICE, VOTE_FOR, VOTE_AMOUNT);
        onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);

        console.log(unicode"✅ Vote with veDEG balance");

        // # --------------------------------------------------------------------//
        // # Should be able to check the vote record # //
        // # --------------------------------------------------------------------//
        
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.numFor, VOTE_AMOUNT);
        assertEq(proposal.numAgainst, 0);

        OnboardProposal.UserVote memory userVote = onboardProposal
            .getUserProposalVote(ALICE, 1);
        assertEq(userVote.choice, VOTE_FOR);
        assertEq(userVote.amount, VOTE_AMOUNT);

        console.log(unicode"✅ Check vote the record");

        // ---------------------------------------------------------- //
        // * Should not be able to vote with both sides choices * //
        // ---------------------------------------------------------- //

        veDEG.mint(ALICE, VOTE_AMOUNT);
        vm.warp(VOTE_TIME + 1);
        vm.expectRevert(OnboardProposal__ChooseBothSides.selector);
        onboardProposal.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        console.log(unicode"✅ Not vote with both sides choices");

        // Stop sending txs from Alice        
        vm.stopPrank();

        // ---------------------------------------------------------- //
        // * Should be able to vote from another user * //
        // ---------------------------------------------------------- //

        veDEG.mint(BOB, VOTE_AMOUNT);
        vm.prank(BOB);
        vm.warp(VOTE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ProposalVoted(1, BOB, VOTE_AGAINST, VOTE_AMOUNT);
        onboardProposal.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        console.log(unicode"✅ Vote from another user");

    }

    function testVoteFuzz(uint256 _choice) public {
        // Start a proposal and start voting
        _proposeVTX();
        _startVoting();

        // ---------------------------------------------------------- //
        // * Should not be able to vote with a wrong choice * //
        // ---------------------------------------------------------- //

        vm.prank(ALICE);
        vm.warp(VOTE_TIME + 1);
        vm.assume(_choice != 1 && _choice != 2);
        vm.expectRevert(OnboardProposal__WrongChoice.selector);
        onboardProposal.vote(1, _choice, VOTE_AMOUNT);

        console.log(unicode"✅ Not vvote with a wrong choice");

    }

    function testSettle() public {
        // Start a proposal and start voting
        _proposeVTX();
        _startVoting();

        // Preparations
        veDEG.mint(ALICE, VOTE_AMOUNT * 2);
        veDEG.mint(BOB, VOTE_AMOUNT * 2);

        vm.prank(ALICE);
        vm.warp(VOTE_TIME + 1);
        onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);

        vm.prank(BOB);
        vm.warp(VOTE_TIME + 1);
        onboardProposal.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        // Take the evm snapshot for test and takes a new snapshot
        uint256 snapshot_1 = vm.snapshot();

        // ---------------------------------------------------------- //
        // * Should not be able to settle before voting period ends * //
        // ---------------------------------------------------------- //

        vm.warp(SETTLE_TIME - 2);
        vm.expectRevert(OnboardProposal__WrongPeriod.selector);
        onboardProposal.settle(1);

        console.log(unicode"✅ Not settle before voting period ends");

        // ---------------------------------------------------------- //
        // * Should be able to settle with TIED * //
        // ---------------------------------------------------------- //

        vm.warp(SETTLE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ProposalSettled(1, TIED_RESULT);
        onboardProposal.settle(1);

        console.log(unicode"✅ Settle with TIED");

        // Should be able to check the record 
        OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
            1
        );
        assertEq(proposal.status, SETTLED_STATUS);
        assertEq(proposal.result, TIED_RESULT);

        console.log(unicode"✅ Check the settled proposal record");

        // ---------------------------------------------------------- //
        // * Should be able to settle with REJECT * //
        // ---------------------------------------------------------- //

        // Revert to the previous snapshot and take a new snapshot
        vm.revertTo(snapshot_1);
        uint256 snapshot_2 = vm.snapshot();

        // Bob vote against, making the result to REJECT
        vm.prank(BOB);
        vm.warp(VOTE_TIME);
        onboardProposal.vote(1, VOTE_AGAINST, VOTE_AMOUNT);

        // Settle the voting
        vm.warp(SETTLE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ProposalSettled(1, REJECT_RESULT);
        onboardProposal.settle(1);

        // Should be able to check the record
        proposal = onboardProposal.getProposal(1);
        assertEq(proposal.status, SETTLED_STATUS);
        assertEq(proposal.result, REJECT_RESULT);

        console.log(unicode"✅ Settle with REJECT");

        // ---------------------------------------------------------- //
        // * Should be able to settle with PASS * //
        // ---------------------------------------------------------- //

        // Revert to the previous snapshot
        vm.revertTo(snapshot_2);
        uint256 snapshot_3 = vm.snapshot();

        // Alice vote for, making the result PASS
        vm.prank(ALICE);
        vm.warp(VOTE_TIME);
        onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);

        // Settle the voting
        vm.warp(SETTLE_TIME + 1);
        vm.expectEmit(false, false, false, true);
        emit ProposalSettled(1, PASS_RESULT);
        onboardProposal.settle(1);

        // Should be able to check the record
        proposal = onboardProposal.getProposal(1);
        assertEq(proposal.status, SETTLED_STATUS);
        assertEq(proposal.result, PASS_RESULT);

        console.log(unicode"✅ Settle with PASS");

        // ---------------------------------------------------------- //
        // * Should be able to settle with FAILED * //
        // ---------------------------------------------------------- //

        vm.revertTo(snapshot_3);

        // mint veDEG so that current vote amount is lower than required amount
        veDEG.mint(address(this), 10000 ether);

        vm.warp(SETTLE_TIME + 10);
        vm.expectEmit(false, false, false, true);
        emit ProposalFailed(1);
        onboardProposal.settle(1);

        console.log(unicode"✅ Settle with FAILED");

        // Should be able to check the record
        proposal = onboardProposal.getProposal(1);
        assertEq(proposal.status, SETTLED_STATUS);
        assertEq(proposal.result, FAILED_RESULT);

    }
}
