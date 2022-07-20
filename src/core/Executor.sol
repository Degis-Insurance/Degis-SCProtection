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
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IInsurancePoolFactory.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../util/Setters.sol";

pragma solidity ^0.8.13;

contract Executor is Ownable, Setters {

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    struct QueuedReport {
        uint256 poolId;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }

    struct QueuedPool {
        string protocolName;
        address protocol;
        uint256 maxCapacity;
        uint256 initialpolicyPricePerShield;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }

    mapping(uint256 => QueuedReport) public queuedReportsById;
    uint256 public poolBuffer;
    mapping(uint256 => QueuedPool) public queuedPoolsById;
    uint256 public reportBuffer;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event QueueReport(uint256 reportId, uint256 poolId, uint256 ends);
    event QueuePool(uint256 proposalId, uint256 maxCapacity, uint256 ends);
    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);
    event NewPoolEecuted(address poolAddress, uint256 proposalId, address protocol);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor () {
        poolBuffer = 3 days;
        reportBuffer = 3 days;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @dev Returns the a queued report
     * @param _reportId The ID of the queued report
     */
    function getQueuedReportById(uint256 _reportId) public view returns (uint256, uint256, bool, bool) {
        require(queuedReportsById[_reportId].pending, "Report not pending");
        QueuedReport memory queuedReport = queuedReportsById[_reportId];
        return (queuedReport.poolId,
        queuedReport.queueEnds,
        queuedReport.pending,
       queuedReport.approved);
    }

    /**
     * @dev Returns the a queued pool
     * @param _proposalId The ID of the queued pool
     */
    function getQueuedPoolsById(uint256 _proposalId) public view returns (string memory, address, uint256, uint256, uint256, bool, bool) {
        require(queuedPoolsById[_proposalId].pending, "Report not pending");
        QueuedPool memory queuedPool = queuedPoolsById[_proposalId];
        return (queuedPool.protocolName,
                queuedPool.protocol,
                queuedPool.maxCapacity,
                queuedPool.initialpolicyPricePerShield,
                queuedPool.queueEnds,
                queuedPool.pending,
                queuedPool.approved);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @dev sets pool and report time buffers
     * @param _poolBuffer time in unix
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
     * @dev sets pool and report time buffers
     * @param _pending state of the proposal
     * @param _approved if report is approved 
     * @param _reportId report id generated on Policy Center
     * @param _poolId pool id generated on Policy Center
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
     * @dev sets pool and report time buffers
     * @param _protocolName name of the protocol
     * @param _proposalId proposal generated by the proposal center
     * @param _protocol protocol token address
     * @param _maxCapacity max capacity suggested
     * @param _initialpolicyPricePerShield initial policy price per shield
     * @param _pending state of the proposal
     * @param _approved if report is approved 
     */
    function queuePool(
        string memory _protocolName,
        uint256 _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _initialpolicyPricePerShield,
        bool _pending,
        bool _approved
    ) public {
        require(msg.sender == proposalCenter, "not sent from proposal center");
        uint256 ends = block.timestamp + poolBuffer;
        queuedPoolsById[_proposalId] = QueuedPool(
            _protocolName,
            _protocol,
            _maxCapacity,
            _initialpolicyPricePerShield,
            ends,
            _pending,
            _approved
        );
        emit QueuePool(_proposalId, _maxCapacity, ends);
    }

    /**
     * @dev executes report according to its decision
     * @param _reportId report id generated on Policy Center
     */
    function executeReport(uint256 _reportId) external onlyOwner {
        require(queuedReportsById[_reportId].pending, "report not pending or not found");
        require(
            block.timestamp > queuedReportsById[_reportId].queueEnds,
            "report not ready"
        );
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            queuedReportsById[_reportId].poolId
        );
        if (queuedReportsById[_reportId].approved) {
            IInsurancePool(pool).liquidatePool();
            IProposalCenter(proposalCenter).liquidateByReportId(
                _reportId,
                true
            );
            emit ReportExecuted(pool, queuedReportsById[_reportId].poolId, _reportId);
        } else {
            IProposalCenter(proposalCenter).setPoolReported(pool, false);
            IProposalCenter(proposalCenter).liquidateByReportId(
                _reportId,
                false
            );
            queuedReportsById[_reportId].pending = false;
        }
        queuedReportsById[_reportId].pending = false;
    }

    /**
     * @dev executes pool proposal according to its decision
     * @param _proposalId proposal id generated on Policy Center
     */
    function executeNewPool(uint256 _proposalId) external onlyOwner returns (address newPool){
        require(queuedPoolsById[_proposalId].pending, "pool not pending");
        require(
            block.timestamp > queuedPoolsById[_proposalId].queueEnds,
            "pool not ready"
        );
        
        if (queuedPoolsById[_proposalId].approved) {
            newPool = IInsurancePoolFactory(insurancePoolFactory).deployPool(
                queuedPoolsById[_proposalId].protocolName,
                queuedPoolsById[_proposalId].protocol,
                queuedPoolsById[_proposalId].maxCapacity,
                queuedPoolsById[_proposalId].initialpolicyPricePerShield
            );
            emit NewPoolEecuted(newPool, _proposalId, queuedPoolsById[_proposalId].protocol);
            return newPool;
        } else {
            IProposalCenter(proposalCenter).setProposal(_proposalId, false);
            queuedPoolsById[_proposalId].pending = false;
        }
    }

    /**
     * @dev emergency function to cancel a report
     * @param _reportId report id generated on Policy Center
     */
    function cancelReport(uint256 _reportId) external onlyOwner {
        require(queuedReportsById[_reportId].pending, "tx not queued");
        queuedReportsById[_reportId].pending = false;
    }

    /**
     * @dev emergency function to cancel a pool proposal
     * @param _proposalId proposal id generated on Policy Center
     */
    function cancelNewPool(uint256 _proposalId) external onlyOwner {
        require(queuedPoolsById[_proposalId].pending, "tx not queued");
        queuedPoolsById[_proposalId].pending = false;
    }
}
