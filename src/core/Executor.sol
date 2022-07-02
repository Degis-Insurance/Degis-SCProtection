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

import "../interfaces/IInsurancePool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";

pragma solidity ^0.8.13;

contract Executor is Ownable {
    struct queuedReport {
        uint256 poolId;
        uint256 queueEnds;
        bool pending;
        bool approved;
    }

    struct queuedPool {
        string protocolName;
        uint256 protocolAddress;
        uint256 reinsuranceSplit;
        uint256 insuranceSplit;
        uint256 maxCapacity;
        uint256 timestamp;
        uint256 queueEnds;
        address proposerAddress;
        bool pending;
        bool approved;
    }

    mapping(uint256 => queuedReport) public queuedReportsById;
    uint256 public poolBuffer = 7 days;
    mapping(uint256 => queuedPool) public queuedPoolsById;
    uint256 public reportBuffer = 3 days;

    address public policyCenterAddress;

    event Queue(uint256 reportId, uint256 poolId, uint256 timestamp);

    function queueReport(
        bool _pending,
        bool _approved,
        uint256 _reportId,
        uint256 _poolId
    ) public {
        require(
            msg.sender == proposalCenterAddress,
            "not sent from proposal center"
        );
        uint256 ends = block.timestamp + reportBuffer;
        queuedReportsById[_reportId] = queuedReport(
            _poolId,
            ends,
            _pending,
            _approved
        );

        emit Queue(_reportId, _poolId, ends);
    }

    function queuePool(
        string _protocolName,
        uint256 _proposalId,
        uint256 _protocolAddress,
        uint256 _reinsuranceSplit,
        uint256 _insuranceSplit,
        uint256 _maxCapacity,
        uint256 _timestamp,
        address _proposerAddress,
        bool _pending,
        bool _approved
    ) public {
        require(
            msg.sender == proposalCenterAddress,
            "not sent from proposal center"
        );
        uint256 ends = block.timestamp + poolBuffer;
        queuedPoolsById[_proposalId] = queuedPool(
            _protocolName,
            _protocolAddress,
            _reinsuranceSplit,
            _insuranceSplit,
            _maxCapacity,
            _timestamp,
            ends,
            _proposerAddress,
            _pending,
            _approved
        );
        emit Queue(_reportId, _poolId, ends);
    }

    function executeReport(uint256 _reportId) external executorOrOwnerOnly {
        require(queuedReportsById[_reportId], "tx not queued");
        require(queuedReportsById[_reportId].pending, "tx already executed");
        require(
            block.timestamp > queuedReportsById[_reportId].queueEnds,
            "tx not ready"
        );
        address poolAddress = IPolicyCenter(policyCenterAddress).poolIds[
            queuedReportsById[_reportId].poolId
        ];
        if (queuedReports[_reportId].approved) {
            IInsurancePool(poolAddress).liquidatePool();
            IProposalCenter(proposalCenterAddress).liquidateAndTransferVeDEG(
                _reportId,
                true
            );
        } else {
            IProposalCenter(proposalCenterAddress).setPoolReported(
                _reportId,
                false
            );
            IProposalCenter(proposalCenterAddress).liquidateAndTransferVeDEG(
                _reportId,
                false
            );
        }
        queuedReportsById.pending = false;
        emit ReportExecuted(_reportId);
    }

    function executeNewPool(uint256 _proposalId) internal executorOrOwnerOnly {
        require(queuedPoolsById[_proposalId], "tx not queued");
        require(
            block.timestamp > queuedPoolsById[_proposalId].queueEnds,
            "tx not ready"
        );
        address poolAddress = IPolicyCenter(policyCenterAddress).poolIds[
            queuedPoolsById[_proposalId].poolId
        ];
        if (queuedPoolsById[_proposalId].approved) {
            IInsurancePoolFactory(insurancePoolFactoryAddress).deployPool(
                queuedPoolsById[_proposalId].protocolName,
                queuedPoolsById[_proposalId].protocolAddress,
                queuedPoolsById[_proposalId].maxCapacity,
                queuedPoolsById[_proposalId].reinsuranceSplit,
                queuedPoolsById[_proposalId].insuranceSplit
            );
        } else {
            IProposalCenter(proposalCenterAddress).transferLiquidatedVeDEG(
                _proposalId,
                false
            );
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
