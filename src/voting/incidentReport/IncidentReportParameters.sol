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
    uint256 constant PENDING_PERIOD = 2 hours;

    // 16 hours for fuji, 2 hours for fujiInternal
    uint256 constant INCIDENT_VOTING_PERIOD = 16 hours;

    uint256 constant EXTEND_PERIOD = 4 hours;
    uint256 constant SAMPLE_PERIOD = 2 hours;

    // // Quorum parameter
    // // TODO: 10% for test
    // uint256 constant INCIDENT_QUORUM_RATIO = 10;

    // DEG threshold for starting a report
    uint256 constant REPORT_THRESHOLD = 10000 ether;

    // DEG reward for correct reporter
    uint256 constant REPORTER_REWARD = 10000 ether;

    // Reward & Punishment ratios
    uint256 constant REWARD_RATIO = 40; // 40% go to winners, 40% reserve
    uint256 constant RESERVE_RATIO = 40;
    uint256 constant DEBT_RATIO = 80; // 80% as the debt to unlock veDEG
}
