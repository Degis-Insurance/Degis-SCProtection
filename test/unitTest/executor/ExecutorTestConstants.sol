// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {OnboardProposalParameters} from "src/voting/onboardProposal/OnboardProposalParameters.sol";
import {IncidentReportParameters} from "src/voting/incidentReport/IncidentReportParameters.sol";

contract ExecutorTestConstants is
    OnboardProposalParameters,
    IncidentReportParameters
{
    uint256 internal constant SCALE = 1e12;

    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant PAYOUT = 1000e6;
    uint256 internal constant LIQUIDITY = 1000 ether;

    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant PROPOSE_TIME = 0;
    uint256 internal constant REPORT_TIME = 0;

    uint256 internal constant PROPOSAL_VOTE_TIME = 0;
    uint256 internal constant INCIDENT_VOTE_TIME = PENDING_PERIOD;

    uint256 internal constant PROPOSAL_SETTLE_TIME =
        PROPOSAL_VOTE_TIME + PROPOSAL_VOTING_PERIOD;
    uint256 internal constant INCIDENT_SETTLE_TIME =
        INCIDENT_VOTE_TIME + INCIDENT_VOTING_PERIOD;
}
