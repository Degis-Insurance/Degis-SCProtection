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
import "../util/ProtocolProtection.sol";

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
contract Executor is ProtocolProtection, VotingParameters {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // if chosen to, executor report could have a buffer timer to prevent abuse of the system
    // from team or organization members
    uint256 public reportBuffer;
    uint256 public poolBuffer;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);

    event NewPoolEecuted(
        address poolAddress,
        uint256 proposalId,
        address protocol
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice              sets pool and report time buffers
     * @param _poolBuffer   time in unix
     * @param _reportBuffer time in unix
     */
    function setBuffers(uint256 _poolBuffer, uint256 _reportBuffer) public {
        poolBuffer = _poolBuffer;
        reportBuffer = _reportBuffer;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice executes a report already settled by vote
     * @param _reportId _id of the report to be executed
     */
    function executeReport(uint256 _reportId) public {
        // get the report
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

        ) = IIncidentReport(incidentReport).reports(_reportId);

        require(status == SETTLED_STATUS, "Report is not ready to be executed");

        require(result == 1, "Report is not passed");

        // execute the pool
        address poolAddress = IPolicyCenter(policyCenter).getInsurancePoolById(
            poolId
        );
        address tokenAddress = IPolicyCenter(policyCenter).tokenByPoolId(
            poolId
        );

        // reward 10% of treasury to reporter
        IPolicyCenter(policyCenter).rewardTreasuryToReporter(reporter);

        // liquidate the pool
        IInsurancePool(poolAddress).liquidatePool();

        // remove pool from protocol registry in insurance pool factory
        // that allows the creation of newe pools for that protocol
        IInsurancePoolFactory(insurancePoolFactory).deregisterAddress(
            tokenAddress
        );
        // IInsurancePoolFactory(poolAddress).deregisterToken()
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
        address newPool = IInsurancePoolFactory(insurancePoolFactory)
            .deployPool(
                proposal.name,
                proposal.protocolAddress,
                proposal.maxCapacity,
                proposal.priceRatio
            );

        // emit the event
        emit NewPoolEecuted(newPool, _proposalId, proposal.protocolAddress);

        return newPool;
    }
}
