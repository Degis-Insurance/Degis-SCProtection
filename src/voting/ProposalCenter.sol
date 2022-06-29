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

import "./interfaces/IInsurancePool.sol";

pragma solidity ^0.8.13;

contract ProposalCenter {
    
    struct Report {
        uint256 poolId;
        uint256 timestamp;
        address reporterAddress;
        uint256 yes;
        uint256 no;
        bool comittee;
        bool team;
        bool pending;
        bool approved;
    }

    struct PoolProposal {
        string protocolName;
        uint256 protocolAddress;
        uint256 reinsuranceSplit;
        uint256 insuranceSplit;
        uint256 timestamp;
        address proposerAddress;
        bool pending;
        bool approved;
    }

    address public DEG;
    address public veDEG;
    address public ComitteeAddress;

    uint256 public reportCounter;
    mapping(uint256 => Report) reportIds;

    uint256 public proposalCounter;
    mapping(uint256 => PoolProposal) proposalIds;
    mapping(uint256 => address) poolAddress;
    mapping(address => bool) poolReported;

    uint256[3] voteWeights = [7000, 2000, 1000];

    event Vote(uint256 _reportId, bool _quorum, string _who);
    event ReportCreated(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress);
    event ReportApproved(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress);
    event ReportRejected(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress);

    event PoolProposalCreated(uint256 _proposalId, uint256 _protocol, uint256 _reinsuranceSplit, uint256 _insuranceSplit, uint256 _timestamp, address _proposerAddress);
    event PoolProposalApproved(uint256 _proposalId, uint256 _protocol, uint256 _reinsuranceSplit, uint256 _insuranceSplit, uint256 _timestamp, address _proposerAddress);
    event PoolProposalRejected(uint256 _proposalId, uint256 _protocol, uint256 _reinsuranceSplit, uint256 _insuranceSplit, uint256 _timestamp, address _proposerAddress);

    function vote(uint256 _reportId, bool _quorum) external {
        require(reportId[_reportId].pending, "Report is not pending");
        uint256 balance = IveDEG(veDEG).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        if(_quorum) {
            reportIds[_reportId].yes += balance;
        } else {
            reportIds[_reportId].no += balance;
        }
        emit Vote(_reportId, _quorum, "veDEG");
    }

    function comitteeVote(uint256 _reportId, bool _quorum) external {
        require(msg.sender == ComitteeAddress, "Only Comittee can vote");
        require(reportId[_reportId].pending, "Report is not pending");
        reportIds[_reportId].comittee = _quorum;

        emit Vote(_reportId, _quorum, "Comittee");
    }

    function teamVote(uint256 _reportId, bool _quorum) external {
        require(msg.sender == ComitteeAddress, "Only Comittee can vote");
        require(reportIds[_reportId].pending, "Report is not pending");
        reportIds[reportId].team = _quorum;

        emit Vote(_reportId, _quorum, "Team");
    }

    function evaluateReportVotes(uint256 _reportId) external {
        require(reportIds[_reportId].pending == true);
        require(reportIds[_reportId].reporterAddress != msg.sender);
        // 1 week for the report to be evaluated
        require(reportId[_reportId].timestamp + 604800 < block.timestamp);

        uint256 weightedYes = reportIds[_reportId].yes * voteWeights[0];
        uint256 weightedNo = reportIds[_reportId].no * voteWeights[0];
        uint256 total = yes + no;
        uint256 weightedComittee = total / voteWeights[0] * voteWeights[1];
        uint256 weightedTeam = total / voteWeights[0] * voteWeights[2];
        reportIds[_reportId].comittee ? weightedYes += weightedComittee : weightedNo += weightedComittee;
        reportIds[_reportId].team ? weightedYes += weightedTeam : weightedNo += weightedTeam;

        if (weightedYes > weightedNo) {
            reportIds[_reportId].approved = true;
            _queueFinishedReport(_reportId);
            emit ReportApproved(_reportId, reportId[_reportId].poolId, reportId[_reportId].timestamp, reportId[_reportId].reporterAddress);
        } else {
            reportIds[_reportId].approved = false;
            poolReported[poolAddress[_poolId]] = false;
            emit ReportRejected(_reportId, reportIds[_reportId].poolId, reportIds[_reportId].timestamp, reportIds[_reportId].reporterAddress);
        }
    }

    function reportPool(uint256 _poolId) external {
        require(!poolReported[poolAddress[_poolId]], "Pool already reported");
        ++reportCounter;
        Report report;
        report.poolId = _poolId;
        report.timestamp = block.timestamp;
        report.reportId = reportCounter;
        report.reporterAddress = msg.sender;
        report.pending = true;
        report.approved = false;

        reportIds[reportCounter] = report;

        IERC20(DEG).transfer(msg.sender, address(this), 1000);

        emit ReportCreated(reportIds[reportCounter].reportId, reportIds[reportCounter].poolId, reportIds[reportCounter].timestamp, reportIds[reportCounter].reporterAddress);
    }
    
    function proposePool(address _protocol, uint256 _reinsuranceSplit, uint256 _insuranceSplit) external {
        ++proposalCounter;
        PoolProposal proposal;
        proposal.protocolName = _protocolName;
        proposal.protocol = _protocol;
        proposal.reinsuranceSplit = _reinsuranceSplit;
        proposal.insuranceSplit = _insuranceSplit;
        proposal.timestamp = block.timestamp;
        proposal.proposerAddress = msg.sender;
        proposal.pending = true;
        proposal.approved = false;

        proposalIds[proposalCounter] = proposal;
        emit PoolProposalCreated(proposalIds[proposalCounter].proposalId, proposalIds[proposalCounter].protocol, proposalIds[proposalCounter].reinsuranceSplit, proposalIds[proposalCounter].insuranceSplit, proposalIds[proposalCounter].timestamp, proposalIds[proposalCounter].proposerAddress);
    }

    function _queueFinishedReport(uint256 _reportId) internal {
        Report report = reportIds[_reportId];
        require(report.pending, "Report is not pending");
        require(report.approved, "Report is not approved");
        bytes32 data = keccak256(abi.encodePacked(report));
        Executor(ExecutorAddress).queueReport(abi.encode(data));
        reportIds[_reportId].pending = false;
    }

    function _queueNewPool(uint256 _proposalId) internal {
        PoolProposal proposal = proposalIds[_proposalId];
        require(proposal.pending, "Proposal is not pending");
        require(proposal.approved, "Proposal is not approved");
        Executor(ExecutorAddress).queuePool(propodsal.protocolName, proposal.protocolAddress, proposal);
        proposalIds[_proposalId].pending = false;
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