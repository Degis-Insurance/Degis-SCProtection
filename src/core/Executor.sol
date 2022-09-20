// SPDX-License-Identifier: GPL-3.0-or-later

/*
 //======================================================================\\
 //======================================================================\\
  *******         **********     ***********     *****     ***********
  *      *        *              *                 *       *
  *        *      *              *                 *       *
  *         *     *              *                 *       *
  *         *     *              *                 *       *
  *         *     **********     *       *****     *       ***********
  *         *     *              *         *       *                 *
  *         *     *              *         *       *                 *
  *        *      *              *         *       *                 *
  *      *        *              *         *       *                 *
  *******         **********     ***********     *****     ***********
 \\======================================================================//
 \\======================================================================//
*/

pragma solidity ^0.8.13;

import "../util/OwnableWithoutContextUpgradeable.sol";
import "./interfaces/ExecutorDependencies.sol";
import "../voting/interfaces/VotingParameters.sol";
import "./interfaces/ExecutorEventError.sol";

import "forge-std/console.sol";

/**
 * @title Executor
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the executor for degis Protocol Protection
 *         The executor is responsible for the execution of the reports and pool proposals
 *         Both administrators or users can execute proposals and reports
 *
 */
contract Executor is
    VotingParameters,
    ExecutorEventError,
    OwnableWithoutContextUpgradeable,
    ExecutorDependencies
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Whether report already executed
    mapping(uint256 => bool) public reportExecuted;

    // Whether proposal already executed
    mapping(uint256 => bool) public proposalExecuted;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize() public initializer {
        __Ownable_init();
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        onlyOwner
    {
        priorityPoolFactory = _priorityPoolFactory;
    }

    function setIncidentReport(address _incidentReport) external onlyOwner {
        incidentReport = _incidentReport;
    }

    function setOnboardProposal(address _onboardProposal) external onlyOwner {
        onboardProposal = _onboardProposal;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Execute a report
     *         The report must already been settled and the result is PASSED
     *         Execution means:
     *             1) Give 10% of protocol income to reporter (SHIELD)
     *             2) Move the total payout amount out of the priority pool (to payout pool)
     *             3) Deploy new generations of CRTokens and PRI-LP tokens
     *
     *         Can not execute a report before the previous liquidation ended
     *
     * @param _reportId Id of the report to be executed
     */
    function executeReport(uint256 _reportId) public {
        // Check and mark the report as "executed"
        if (reportExecuted[_reportId]) revert Executor__AlreadyExecuted();
        reportExecuted[_reportId] = true;

        IIncidentReport.Report memory report = IIncidentReport(incidentReport)
            .getReport(_reportId);

        if (report.status != SETTLED_STATUS)
            revert Executor__ReportNotSettled();
        if (report.result != PASS_RESULT) revert Executor__ReportNotPassed();

        // Executed callback function
        IIncidentReport(incidentReport).executed(report.poolId);

        // Give 10% of treasury to the reporter
        ITreasury(treasury).rewardReporter(report.poolId, report.reporter);

        IPriorityPoolFactory factory = IPriorityPoolFactory(
            priorityPoolFactory
        );

        // // Unpause the priority pool and protection pool
        // factory.pausePriorityPool(report.poolId, false);

        // IIncidentReport(incidentReport).setReported(report.poolId, false);

        // Liquidate the pool
        (, address poolAddress, , , ) = factory.pools(report.poolId);
        IPriorityPool(poolAddress).liquidatePool(report.payout);

        emit ReportExecuted(poolAddress, report.poolId, _reportId);
    }

    /**
     * @notice Execute the proposal
     *         The proposal must already been settled and the result is PASSED
     *         New priority pool will be deployed with parameters
     *
     * @param _proposalId Proposal id
     */
    function executeProposal(uint256 _proposalId)
        external
        returns (address newPriorityPool)
    {
        // Check and mark the proposal as "executed"
        if (proposalExecuted[_proposalId]) revert Executor__AlreadyExecuted();
        proposalExecuted[_proposalId] = true;

        IOnboardProposal.Proposal memory proposal = IOnboardProposal(
            onboardProposal
        ).getProposal(_proposalId);

        if (proposal.status != SETTLED_STATUS)
            revert Executor__ProposalNotSettled();
        if (proposal.result != PASS_RESULT)
            revert Executor__ProposalNotPassed();

        // Execute the proposal
        newPriorityPool = IPriorityPoolFactory(priorityPoolFactory).deployPool(
            proposal.name,
            proposal.protocolToken,
            proposal.maxCapacity,
            proposal.basePremiumRatio
        );

        emit NewPoolExecuted(
            newPriorityPool,
            _proposalId,
            proposal.protocolToken
        );
    }
}
