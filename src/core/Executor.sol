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

    // queued reports are stored to be executed in the future
    // enacting a buffer time to provide trust to the user
    struct QueuedReport {
        uint256 poolId;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }
    mapping(uint256 => QueuedReport) public queuedReportsById;
    uint256 public poolBuffer;

    // queued pools are stored to be executed in the future
    // enacting a buffer time to provide trust to the user
    struct QueuedPool {
        string protocolName;
        address protocol;
        uint256 maxCapacity;
        uint256 policyPricePerShield;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }
    mapping(uint256 => QueuedPool) public queuedPoolsById;
    uint256 public reportBuffer;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event QueueReport(uint256 reportId, uint256 poolId, uint256 ends);
    event QueuePool(uint256 proposalId, uint256 maxCapacity, uint256 ends);
    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);
    event NewPoolEecuted(
        address poolAddress,
        uint256 proposalId,
        address protocol
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor() {
        poolBuffer = 1 days;
        reportBuffer = 1 days;
    }

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
     * @notice          sets pool and report time buffers
     * @param _pending  state of the proposal
     * @param _approved if report is approved
     * @param _reportId report id generated on Policy Center
     * @param _poolId   pool id generated on Policy Center
     */
    function queueReport(
        bool _pending,
        bool _approved,
        uint256 _reportId,
        uint256 _poolId
    ) public {
        require(msg.sender == proposalCenter, "not sent from proposal center");
        uint256 ends = block.timestamp + reportBuffer;
        queuedReportsById[_reportId] = QueuedReport(
            _poolId,
            ends,
            _pending,
            _approved
        );

        emit QueueReport(_reportId, _poolId, ends);
    }

    /**
     * @notice sets pool and report time buffers
     * @param _protocolName         name of the protocol
     * @param _proposalId           proposal generated by the proposal center
     * @param _protocol             protocol token address
     * @param _maxCapacity          max capacity suggested
     * @param _policyPricePerToken initial policy price per shield
     * @param _pending              state of the proposal
     * @param _approved             if report is approved
     */
    function queuePool(
        string memory _protocolName,
        uint256 _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _policyPricePerToken,
        bool _pending,
        bool _approved
    ) public {
        require(msg.sender == proposalCenter, "not sent from proposal center");
        uint256 ends = block.timestamp + poolBuffer;
        // store pool in queuedPoolsById
        queuedPoolsById[_proposalId] = QueuedPool(
            _protocolName,
            _protocol,
            _maxCapacity,
            _policyPricePerToken,
            ends,
            _pending,
            _approved
        );
        emit QueuePool(_proposalId, _maxCapacity, ends);
    }

    /**
     * @notice executes report according to its decision
     * @param _reportId report id generated on Policy Center
     */
    function executeReport(uint256 _reportId) external onlyOwner {
        require(
            queuedReportsById[_reportId].pending,
            "report not pending or not found"
        );
        require(
            block.timestamp > queuedReportsById[_reportId].queueEnds,
            "report not ready"
        );
        // execute report, update pool and liquidate
        // update states on other cotnracts
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            queuedReportsById[_reportId].poolId
        );
        if (queuedReportsById[_reportId].approved) {
            IInsurancePool(pool).liquidatePool();
            emit ReportExecuted(
                pool,
                queuedReportsById[_reportId].poolId,
                _reportId
            );
        } else {
            IProposalCenter(proposalCenter).setPoolReported(pool, false);
            queuedReportsById[_reportId].pending = false;
        }
        IProposalCenter(proposalCenter).rewardByReportId(
            _reportId,
            queuedReportsById[_reportId].approved
        );
        queuedReportsById[_reportId].pending = false;
    }

    /**
     * @notice executes pool proposal according to its decision
     * @param _proposalId proposal id generated on Policy Center
     * @return newPool    address of the new pool
     */
    function executeNewPool(uint256 _proposalId)
        external
        onlyOwner
        returns (address newPool)
    {
        require(queuedPoolsById[_proposalId].pending, "pool not pending");
        require(
            block.timestamp > queuedPoolsById[_proposalId].queueEnds,
            "pool not ready"
        );
        // deploy pool and update states on other contracts
        if (queuedPoolsById[_proposalId].approved) {
            newPool = IInsurancePoolFactory(insurancePoolFactory).deployPool(
                queuedPoolsById[_proposalId].protocolName,
                queuedPoolsById[_proposalId].protocol,
                queuedPoolsById[_proposalId].maxCapacity,
                queuedPoolsById[_proposalId].policyPricePerShield
            );
            emit NewPoolEecuted(
                newPool,
                _proposalId,
                queuedPoolsById[_proposalId].protocol
            );
            return newPool;
        } else {
            IProposalCenter(proposalCenter).setProposal(_proposalId, false);
            queuedPoolsById[_proposalId].pending = false;
        }
    }

    /**
     * @notice emergency function to cancel a report
     * @param _reportId report id generated on Policy Center
     */
    function cancelReport(uint256 _reportId) external onlyOwner {
        require(queuedReportsById[_reportId].pending, "tx not queued");
        queuedReportsById[_reportId].pending = false;
    }

    /**
     * @notice emergency function to cancel a pool proposal
     * @param _proposalId proposal id generated on Policy Center
     */
    function cancelNewPool(uint256 _proposalId) external onlyOwner {
        require(queuedPoolsById[_proposalId].pending, "tx not queued");
        queuedPoolsById[_proposalId].pending = false;
    }
}
