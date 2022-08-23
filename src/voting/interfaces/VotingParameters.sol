// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

abstract contract VotingParameters {
    // Status parameters for a voting
    uint256 constant INIT_STATUS = 0;
    uint256 constant PENDING_STATUS = 1;
    uint256 constant VOTING_STATUS = 2;
    uint256 constant SETTLED_STATUS = 3;
    uint256 constant CLOSE_STATUS = 404;

    // Result parameters for a voting
    uint256 constant INIT_RESULT = 0;
    uint256 constant PASS_RESULT = 1;
    uint256 constant REJECT_RESULT = 2;
    uint256 constant TIED_RESULT = 3;
    uint256 constant FAILED_RESULT = 4;

}
