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

pragma solidity ^0.8.13;

/**
 * @title Executor
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the executor for degis Protocol Protection
 *         The executor is responsible for the execution of the reports and pool proposals
 *         Both administrators or users can execute proposals and reports out of self interest
 *
 */
contract Executor is
    ExecutorDependencies,
    VotingParameters,
    OwnableWithoutContext
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

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

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        _setPolicyCenter(_policyCenter);
    }

    function setProtectionPool(address _protectionPool) external onlyOwner {
        _setProtectionPool(_protectionPool);
    }

    function setIncidentReport(address _incidentReport) external onlyOwner {
        _setIncidentReport(_incidentReport);
    }

    function setOnboardProposal(address _onboardProposal) external onlyOwner {
        _setOnboardProposal(_onboardProposal);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Execute a report
     *         The report must already been settled and the result is PASSED
     *         Execution means:
     *             1) Give 10% of protocol income to reporter (SHIELD)
     *             2) Mark the priority pool as "liquidated"
     *             3) Move the total payout amount out of the priority pool (to payout pool)
     *
     *         Can not execute a report before the previous liquidation ended
     *
     * @param _reportId Id of the report to be executed
     */
    function executeReport(uint256 _reportId) public {
        // Get the report
        (
            uint256 poolId,
            ,
            address reporter,
            ,
            ,
            ,
            ,
            uint256 status,
            uint256 result,
            ,
            uint256 payout
        ) = IIncidentReport(incidentReport).reports(_reportId);

        require(status == SETTLED_STATUS, "Report is not ready to be executed");
        require(result == 1, "Report is not passed");

        // Give 10% of treasury to the reporter
        ITreasury(treasury).rewardReporter(poolId, reporter);

        IPriorityPoolFactory factory = IPriorityPoolFactory(
            priorityPoolFactory
        );

        // execute the pool
        (, address poolAddress, , , ) = factory.pools(poolId);

        require(
            block.timestamp > IPriorityPool(poolAddress).endLiquidationDate(),
            "Previous liquidation not end"
        );

        // Mark the pool as liquidated
        IPriorityPool(poolAddress).liquidatePool(payout);

        // emit the event
        emit ReportExecuted(poolAddress, poolId, _reportId);
    }

    /**
     * @notice Settle the proposal
     *
     * @param _proposalId Proposal id
     */
    function executeProposal(uint256 _proposalId) external returns (address) {
        IOnboardProposal.Proposal memory proposal = IOnboardProposal(
            onboardProposal
        ).getProposal(_proposalId);

        require(proposal.status == SETTLED_STATUS, "Not settled");
        require(proposal.result == 1, "Has not been approved");

        // execute the proposal
        address newPool = IPriorityPoolFactory(priorityPoolFactory).deployPool(
            proposal.name,
            proposal.protocolAddress,
            proposal.maxCapacity,
            proposal.priceRatio
        );

        // emit the event
        emit NewPoolExecuted(newPool, _proposalId, proposal.protocolAddress);

        return newPool;
    }
}
