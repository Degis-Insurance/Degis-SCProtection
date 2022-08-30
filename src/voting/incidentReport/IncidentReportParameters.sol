// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/VotingParameters.sol";

abstract contract IncidentReportParameters is VotingParameters {
    // Cool down time parameter
    // If you submitted a wrong report, you cannot start another within cooldown period
    uint256 public constant COOLDOWN_WRONG_REPORT = 7 days;

    // TODO: change parameters
    // Voting time length parameters
    uint256 constant PENDING_PERIOD = 2 hours;

    uint256 constant INCIDENT_VOTING_PERIOD = 4 hours;

    uint256 constant EXTEND_PERIOD = 1 hours;
    uint256 constant SAMPLE_PERIOD = 1 hours;

    // Quorum parameter
    uint256 constant INCIDENT_QUORUM_RATIO = 10;

    // DEG threshold for starting a report
    uint256 constant REPORT_THRESHOLD = 10000 ether;

    // DEG reward for correct reporter
    uint256 constant REPORTER_REWARD = 10000 ether;

    // Punishment for those who vote wrong
    uint256 constant REWARD_RATIO = 40; // 40% go to winners, 40% reserve
    uint256 constant RESERVE_RATIO = 40;

    uint256 constant DEBT_RATIO = 80; // 80% as the debt to unlock veDEG
}
