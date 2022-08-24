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
    ContractSetupBaseTest,
    OnboardProposalParameters,
    IncidentReportParameters,
    OnboardProposalEventError,
    IncidentReportEventError
{
    address internal ALICE = mkaddr("Alice");
    address internal BOB = mkaddr("Bob");
    address internal CHARLIE = mkaddr("Charlie");

    uint256 internal constant CAPACITY_1 = 40;
    uint256 internal constant CAPACITY_2 = 30;
    uint256 internal constant CAPACITY_3 = 40;

    uint256 internal constant PREMIUMRATIO_1 = 200;
    uint256 internal constant PREMIUMRATIO_2 = 250;
    uint256 internal constant PREMIUMRATIO_3 = 400;

    uint256 internal constant PAYOUT = 1000e6;

    uint256 internal constant VOTE_FOR = 1;
    uint256 internal constant VOTE_AGAINST = 2;
    uint256 internal constant VOTE_AMOUNT = 100 ether;

    uint256 internal constant PROPOSE_TIME = 0;
    uint256 internal constant VOTE_TIME = 1;
    uint256 internal constant SETTLE_TIME = VOTE_TIME + VOTING_PERIOD;

    IPriorityPool internal joePool;
    IPriorityPool internal ptpPool;
    IPriorityPool internal gmxPool;

    MockERC20 internal joe;
    MockERC20 internal ptp;
    MockERC20 internal gmx;

    function setUp() public {
        setUpContracts();
        // Deploy one protocol token
        joe = new MockERC20("JoeToken", "JOE", 18);

        // Deploy one protocol pool by owner
        joePool = IPriorityPool(
            priorityPoolFactory.deployPool(
                "TraderJoe",
                address(joe),
                CAPACITY_1,
                PREMIUMRATIO_1
            )
        );

        // Proopose a new protocol pool
        deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
        vm.warp(VOTE_TIME);
        vm.prank(CHARLIE);
        onboardProposal.propose(
            "Platypus",
            address(ptpPool),
            CAPACITY_2,
            PREMIUMRATIO_2
        );
    }
    
}
