// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/VotingParameters.sol";

abstract contract IncidentReportParameters is VotingParameters {
    // Cool down time parameter
    // If you submitted a wrong report, you cannot start another within cooldown period
    uint256 public constant COOLDOWN_WRONG_REPORT = 7 days;

    // TODO: change parameters
    // Voting time length parameters
    // uint256 constant PENDING_PERIOD = 3 days;
    uint256 public constant PENDING_PERIOD = 2 hours;

    // 16 hours for fuji, 2 hours for fujiInternal
    uint256 public constant INCIDENT_VOTING_PERIOD = 5 hours;

    uint256 public constant EXTEND_PERIOD = 1 hours;
    uint256 public constant SAMPLE_PERIOD = 1 hours;

    // // Quorum parameter
    // // TODO: 10% for test
    uint256 public constant INCIDENT_QUORUM_RATIO = 10;

    // DEG threshold for starting a report
    uint256 public constant REPORT_THRESHOLD = 10000 ether;

    // DEG reward for correct reporter
    uint256 public constant REPORTER_REWARD = 10000 ether;

    // Reward & Punishment ratios
    uint256 public constant REWARD_RATIO = 40; // 40% go to winners, 40% reserve
    uint256 public constant RESERVE_RATIO = 40;
    uint256 public constant DEBT_RATIO = 80; // 80% as the debt to unlock veDEG

    // 2 extra rounds at most
    uint256 public constant MAX_EXTEND_ROUND = 2;
}
