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
contract Executor is ProtocolProtection {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Reports struct to be executed.
    struct Report {
        uint256 poolId;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }
    uint256 public reportBuffer;


    // pool struct to be executed
    struct Pool {
        string protocolName;
        address protocol;
        uint256 maxCapacity;
        uint256 policyPricePerShield;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }
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

    function executeReport(uint256 _reportId) public {
        // get the report
        Report memory report = IIncidentReport(incidentReport).getReport(_reportId);
        // execute the pool
        address poolAddress = IPolicyCenter(policyCenter).getInsurancePoolById(report.poolId);
        IInsurancePool(poolAddress).liquidatePool();
        // emit the event
        ReportExecuted(poolAddress, report.poolId, _reportId);
    }

    function executePool(uint256 _poolId) public {
        // get the pool
        Pool memory proposal = IOnboardProposal(onboardProposal).getPool(_poolId);

        address poolAddress = IPolicyCenter(policyCenter).getInsurancePoolById(_poolId);

        IInsurancePoolFactory(insurancePoolFactory)
        .deployPool(proposal.name, proposal.protocolToken, proposal.maxCapacity, proposal.policyPricePerShield);
        // emit the event
        NewPoolEecuted(poolAddress, _poolId, proposal.protocolToken);
    }
    
}
