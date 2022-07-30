// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./VotingResultParameters.sol";

abstract contract OnBoardProposalParameters is VotingResultParameters {
    // Status parameters for a report
    uint256 constant INIT_STATUS = 0;
    uint256 constant PENDING_STATUS = 1;
    uint256 constant VOTING_STATUS = 2;
    uint256 constant SETTLED_STATUS = 3;
    uint256 constant CLOSE_STATUS = 404;

    uint256 constant VOTING_PERIOD = 3 days;

    // minimum 50% votes
    uint256 constant QUORUM_RATIO = 50;
}
