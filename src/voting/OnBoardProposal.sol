// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../util/ProtocolProtection.sol";

import "./interfaces/OnBoardProposalParameters.sol";

contract OnBoardProposal is ProtocolProtection, OnBoardProposalParameters {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Total number of reports
    uint256 public proposalCounter;

    struct Proposal {
        uint256 proposeTimestamp;
        address proposer;
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 poolId;
    }
    mapping(uint256 => Proposal) public proposals;

    function propose(
        string calldata _name,
        address _token,
        uint256 _maxCapacity
    ) external {
        require(
            !IInsurancePoolFactory(insurancePoolFactory).registered(_token),
            "Already exist"
        );

        uint256 currentProposalCounter = ++proposalCounter;

        Proposal storage proposal = proposals[currentProposalCounter];
        proposal.proposer = msg.sender;
        proposal.proposeTimestamp = block.timestamp;
    }

    function vote() external {}
}
