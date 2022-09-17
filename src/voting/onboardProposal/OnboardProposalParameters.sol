// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/VotingParameters.sol";

abstract contract OnboardProposalParameters is VotingParameters {
    // TODO: Parameters for test
    //       2 hours for fujiInternal, 18 hours for fuji
    uint256 public constant PROPOSAL_VOTING_PERIOD = 5 hours;

    // minimum 50% votes
    // // TODO: 10% when test
    // uint256 public constant PROPOSAL_QUORUM_RATIO = 10;

    // DEG threshold for starting a report
    uint256 public constant PROPOSE_THRESHOLD = 10000 ether;

    // 10000 = 100%
    uint256 public constant MAX_CAPACITY_RATIO = 10000;
}
