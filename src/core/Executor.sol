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
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";

pragma solidity ^0.8.13;

contract Executor is Ownable {
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
        uint256 timestamp;
        uint256 queueEnds;
        address proposer;
        bool pending;
        bool approved;
    }

    mapping(uint256 => QueuedReport) public queuedReportsById;
    uint256 public poolBuffer = 7 days;
    mapping(uint256 => QueuedPool) public queuedPoolsById;
    uint256 public reportBuffer = 3 days;

    address public DEG;
    address public veDEG;
    address public shield;
    address public insurancePoolFactory;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;
    address public premiumVault;
    address public insurancePool;

    event Queue(uint256 reportId, uint256 poolId, uint256 timestamp);
    event ReportExecuted(uint256 reportId);

    modifier ownerOrExecutorOnly() {
        require(
            msg.sender == owner() || msg.sender == executor,
            "Only owner or executor can call this function"
        );
        _;
    }

    function setDeg(address _deg) external onlyOwner {
        DEG = _deg;
    }

    function setVeDeg(address _veDeg) external onlyOwner {
        veDEG = _veDeg;
    }

    function setShield(address _shield) external onlyOwner {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        policyCenter = _policyCenter;
    }

    function setProposalCenter(address _proposalCenter) external onlyOwner {
        proposalCenter = _proposalCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        reinsurancePool = _reinsurancePool;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory) external onlyOwner {
        insurancePoolFactory = _insurancePoolFactory;
    }

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

        emit Queue(_reportId, _poolId, ends);
    }

    function queuePool(
        string memory _protocolName,
        uint256 _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _timestamp,
        address _proposer,
        bool _pending,
        bool _approved
    ) public {
        require(msg.sender == proposalCenter, "not sent from proposal center");
        uint256 ends = block.timestamp + poolBuffer;
        queuedPoolsById[_proposalId] = QueuedPool(
            _protocolName,
            _protocol,
            _maxCapacity,
            _timestamp,
            ends,
            _proposer,
            _pending,
            _approved
        );
        emit Queue(_proposalId, _maxCapacity, ends);
    }

    function executeReport(uint256 _reportId) external ownerOrExecutorOnly {
        require(queuedReportsById[_reportId].pending, "tx already executed");
        require(
            block.timestamp > queuedReportsById[_reportId].queueEnds,
            "tx not ready"
        );
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            queuedReportsById[_reportId].poolId
        );
        if (queuedReportsById[_reportId].approved) {
            IInsurancePool(pool).liquidatePool();
            IProposalCenter(proposalCenter).liquidateAndTransferVeDEG(
                _reportId,
                true
            );
        } else {
            IProposalCenter(proposalCenter).setPoolReported(pool, false);
            IProposalCenter(proposalCenter).liquidateAndTransferVeDEG(
                _reportId,
                false
            );
        }
        queuedReportsById[_reportId].pending = false;
        emit ReportExecuted(_reportId);
    }

    function executeNewPool(uint256 _proposalId) external ownerOrExecutorOnly {
        require(queuedPoolsById[_proposalId].pending, "tx not queued");
        require(
            block.timestamp > queuedPoolsById[_proposalId].queueEnds,
            "tx not ready"
        );
        if (queuedPoolsById[_proposalId].approved) {
            IInsurancePoolFactory(insurancePoolFactory).deployPool(
                queuedPoolsById[_proposalId].protocolName,
                queuedPoolsById[_proposalId].protocol,
                queuedPoolsById[_proposalId].maxCapacity
            );
        } else {
            IProposalCenter(proposalCenter).setProposal(_proposalId, false);
        }
    }
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //
}
