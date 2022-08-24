// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface ExecutorEventError {
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    error Executor__ReportNotSettled();
    error Executor__ReportNotPassed();
    error Executor__ProposalNotSettled();
    error Executor__ProposalNotPassed();
}
