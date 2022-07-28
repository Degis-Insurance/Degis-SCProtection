// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

abstract contract IncidentReportParameters {
    // Status parameters for a report
    uint256 constant INIT_STATUS = 0;
    uint256 constant PENDING_STATUS = 1;
    uint256 constant VOTING_STATUS = 2;

    // Result parameters for a report
    uint256 constant INIT_RESULT = 0;
    uint256 constant PASS_RESULT = 1;
    uint256 constant REJECT_RESULT = 2;
    uint256 constant TIED_RESULT = 3;

    // Cool down time parameter
    // If you submitted a wrong report, you cannot start another within cooldown period
    uint256 public constant COOLDOWN_WRONGREPORT = 7 days;

    // Voting time length parameters
    uint256 constant VOTING_PERIOD = 3 days;
    uint256 constant EXTEND_PERIOD = 1 days;
    uint256 constant SAMPLE_PERIOD = 1 days;

    // Quorum parameter
    uint256 constant QUORUM_RATIO = 30;
}
