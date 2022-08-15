// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface OnboardProposalErrorEvent {
    event NewProposal(
        string name,
        address token,
        address proposer,
        uint256 maxCapacity,
        uint256 priceRatio
    );

    event VotingStart(uint256 proposalId, uint256 timestamp);

    event ProposalClosed(uint256 proposalId);

    event ProposalVoted(
        uint256 proposalId,
        address indexed user,
        uint256 voteFor,
        uint256 amount
    );

    event ProposalSettled(uint256 proposalId, uint256 result);

    event ProposalFailed(uint256 proposalId);

    event Claimed(uint256 proposalId, address user, uint256 amount);
}
