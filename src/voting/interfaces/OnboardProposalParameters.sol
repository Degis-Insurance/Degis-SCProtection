// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./VotingParameters.sol";

abstract contract OnboardProposalParameters is VotingParameters {
    // TODO: change parameters
    // uint256 constant VOTING_PERIOD = 3 days;
    uint256 constant VOTING_PERIOD = 2 hours;

    // minimum 50% votes
    uint256 constant QUORUM_RATIO = 50;

    // DEG threshold for starting a report
    uint256 constant REPORT_THRESHOLD = 1000 ether;

    uint256 constant MAX_CAPACITY_RATIO = 100;
}
