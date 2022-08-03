// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./VotingParameters.sol";

abstract contract IncidentReportParameters is VotingParameters {
    // Cool down time parameter
    // If you submitted a wrong report, you cannot start another within cooldown period
    uint256 public constant COOLDOWN_WRONG_REPORT = 7 days;

    // Voting time length parameters
    uint256 constant PENDING_PERIOD = 3 days;
    uint256 constant VOTING_PERIOD = 3 days;
    uint256 constant EXTEND_PERIOD = 1 days;
    uint256 constant SAMPLE_PERIOD = 1 days;

    // Quorum parameter
    uint256 constant QUORUM_RATIO = 30;

    // DEG threshold for starting a report
    uint256 constant REPORT_THRESHOLD = 1000 ether;

    // DEG reward for correct reporter
    uint256 constant REPORTER_REWARD = 1000 ether;

    // Punishment for those who vote wrong
    uint256 constant PUNISHMENT_RATIO = 40; // 40% go to winners, 40% reserve
    uint256 constant DEBT_RATIO = 80; // 80% as the debt to unlock veDEG

    // Scale when calculating rewards
    uint256 constant SCALE = 1e12;
}
