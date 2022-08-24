// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./utils/ContractSetupTest.sol";
import "./ProposalTest.t.sol";
import "./IncidentTest.t.sol";

import "src/interfaces/IOnboardProposal.sol";
import "src/interfaces/IPriorityPool.sol";

import "src/voting/onboardProposal/OnboardProposalParameters.sol";
import "src/voting/onboardProposal/OnboardProposalEventError.sol";
import "src/voting/incidentReport/IncidentReportParameters.sol";
import "src/voting/incidentReport/IncidentReportEventError.sol";

contract ExecutorTest is
    ContractSetupBaseTest
{

    function setUp() public {
        setUpContracts();

        // ProposalTest.testSettle();
        // IncidentTest.testSettle();
    }
}
