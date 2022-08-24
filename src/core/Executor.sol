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
import "../util/OwnableWithoutContext.sol";

import "./interfaces/ExecutorDependencies.sol";

import "../voting/interfaces/VotingParameters.sol";

import "./interfaces/ExecutorEventError.sol";

pragma solidity ^0.8.13;

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
    ExecutorDependencies,
    VotingParameters,
    ExecutorEventError,
    OwnableWithoutContext
{
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);

    event NewPoolExecuted(
        address poolAddress,
        uint256 proposalId,
        address protocol
    );

    constructor() OwnableWithoutContext(msg.sender) {}

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        onlyOwner
    {
        _setPriorityPoolFactory(_priorityPoolFactory);
    }

    function setIncidentReport(address _incidentReport) external onlyOwner {
        _setIncidentReport(_incidentReport);
    }

    function setOnboardProposal(address _onboardProposal) external onlyOwner {
        _setOnboardProposal(_onboardProposal);
    }

    function setTreasury(address _treasury) external onlyOwner {
        _setTreasury(_treasury);
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
        // Get the report
        IIncidentReport.Report memory report = IIncidentReport(incidentReport)
            .getReport(_reportId);

        if (report.status != SETTLED_STATUS)
            revert Executor__ReportNotSettled();
        if (report.result != 1)
            revert Executor__ReportNotPassed();

        // Give 10% of treasury to the reporter
        ITreasury(treasury).rewardReporter(report.poolId, report.reporter);

        IPriorityPoolFactory factory = IPriorityPoolFactory(
            priorityPoolFactory
        );

        // execute the pool
        (, address poolAddress, , , ) = factory.pools(report.poolId);

        // Liquidate the pool
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
        IOnboardProposal.Proposal memory proposal = IOnboardProposal(
            onboardProposal
        ).getProposal(_proposalId);

        if (proposal.status != SETTLED_STATUS)
            revert Executor__ProposalNotSettled();
        if (proposal.result != 1)
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
