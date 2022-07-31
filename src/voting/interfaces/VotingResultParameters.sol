// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

abstract contract VotingResultParameters {
    // Result parameters for a report
    uint256 constant INIT_RESULT = 0;
    uint256 constant PASS_RESULT = 1;
    uint256 constant REJECT_RESULT = 2;
    uint256 constant TIED_RESULT = 3;
}
