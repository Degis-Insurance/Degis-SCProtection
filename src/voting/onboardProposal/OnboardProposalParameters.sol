// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/VotingParameters.sol";

abstract contract OnboardProposalParameters is VotingParameters {

    // TODO: Parameters for test
    uint256 constant PROPOSAL_VOTING_PERIOD = 4 hours;

    // minimum 50% votes
    uint256 constant PROPOSAL_QUORUM_RATIO = 10;

    // DEG threshold for starting a report
    uint256 constant PROPOSE_THRESHOLD = 10000 ether;

    // 100 = 100%
    uint256 constant MAX_CAPACITY_RATIO = 100;

}
