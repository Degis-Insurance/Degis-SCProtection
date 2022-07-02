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
import "./interfaces/IReinsurancePool.sol";
import "./interfaces/IPolicyCenter.sol";
import "./interfaces/IveDEG.sol";

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
        address[] voted;
        mapping(address => bool) confirmsReport;
    }

    struct PoolProposal {
        string protocolName;
        uint256 protocolAddress;
        uint256 reinsuranceSplit;
        uint256 insuranceSplit;
        uint256 maxCapacity;
        uint256 timestamp;
        address proposerAddress;
        bool pending;
        bool approved;
    }

    // addresses
    address public DEG;
    address public veDEG;
    address public insurancePool;
    address public reinsurancePool;
    address public ComitteeAddress;

    uint256 public reportCounter;
    // refer to users who have submitted reports in here
    mapping(uint256 => Report) public reportIds;

    uint256 public proposalCounter;
    mapping(uint256 => PoolProposal) public proposalIds;
    // refer to pool addresses by accessing policy center
    mapping(address => bool) public poolReported;
    mapping(address => bool) public poolProposed;

    uint256[3] public voteWeights = [7000, 2000, 1000];

    event Vote(uint256 _reportId, bool _quorum, string _who);
    event ReportCreated(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress
    );
    event ReportApproved(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress
    );
    event ReportRejected(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress
    );

    event PoolProposalCreated(
        uint256 _proposalId,
        uint256 _protocol,
        uint256 _reinsuranceSplit,
        uint256 _insuranceSplit,
        uint256 _maxCapacity,
        uint256 _timestamp,
        address _proposerAddress
    );
    event PoolProposalApproved(
        uint256 _proposalId,
        uint256 _protocol,
        uint256 _reinsuranceSplit,
        uint256 _insuranceSplit,
        uint256 _timestamp,
        address _proposerAddress
    );
    event PoolProposalRejected(
        uint256 _proposalId,
        uint256 _protocol,
        uint256 _reinsuranceSplit,
        uint256 _insuranceSplit,
        uint256 _timestamp,
        address _proposerAddress
    );

    function setVoteWeights(uint256[3] _voteWeights) external onlyOwner {
        require(
            _voteWeights[0] + _voteWeights[1] + _voteWeights[2] == 10000,
            "vote weights must sum to 10000"
        );
        voteWeights = _voteWeights;
    }

    function setDeg(address _deg) external onlyOwner {
        DEG = _deg;
    }

    function setVeDeg(address _veDeg) external onlyOwner {
        veDEG = _veDeg;
    }

    function setPolicyCenter(address _insurancePool) external onlyOwner {
        insurancePool = _insurancePool;
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        reinsurancePool = _reinsurancePool;
    }

    function setCommitteeAddress(address _committeeAddress) external onlyOwner {
        ComitteeAddress = _committeeAddress;
    }

    function setPoolReported(address _poolAddress, bool _decision)
        external
        executorOrOwnerOnly
    {
        poolReported(_poolAddress, _decision);
    }

    function vote(uint256 _reportId, bool _quorum) external {
        require(reportId[_reportId].pending, "Report is not pending");
        address[] voted = reportId[_reportId].voted;
        uint256 length = voted.length;
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "You have already voted");
        }
        uint256 balance = IveDEG(veDEG).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // 1/5 of veDEG is locked.  lockVeDeg makes it disposable
        IveDEG(veDEG).lockVeDEG(msg.sender, balance / 5);
        if (_quorum) {
            reportIds[_reportId].yes += balance;
            reportIds[_reportId].confirmsReport[msg.sender] = true;
        } else {
            reportIds[_reportId].no += balance;
            reportIds[_reportId].confirmsReport[msg.sender] = false;
        }
        reportId[_reportId].voted.push(msg.sender);
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
        require(reportIds[_reportId].pending, "report not pending");
        require(
            reportIds[_reportId].reporterAddress != msg.sender,
            "reporter cannot evaluate"
        );
        // 1 week for the report to be evaluated
        require(reportId[_reportId].timestamp + 604800 < block.timestamp);

        uint256 weightedYes = reportIds[_reportId].yes * voteWeights[0];
        uint256 weightedNo = reportIds[_reportId].no * voteWeights[0];
        uint256 total = yes + no;
        require(total > IveDEG(veDEG).totalSupply() / 2, "Not enough votes");
        uint256 weightedComittee = (total / voteWeights[0]) * voteWeights[1];
        uint256 weightedTeam = (total / voteWeights[0]) * voteWeights[2];
        reportIds[_reportId].comittee
            ? weightedYes += weightedComittee
            : weightedNo += weightedComittee;
        reportIds[_reportId].team
            ? weightedYes += weightedTeam
            : weightedNo += weightedTeam;

        if (weightedYes > weightedNo) {
            reportIds[_reportId].approved = true;
            emit ReportApproved(
                _reportId,
                reportId[_reportId].poolId,
                reportId[_reportId].timestamp,
                reportId[_reportId].reporterAddress
            );
        } else {
            reportIds[_reportId].approved = false;
            poolReported[poolAddress[_poolId]] = false;
            emit ReportRejected(
                _reportId,
                reportIds[_reportId].poolId,
                reportIds[_reportId].timestamp,
                reportIds[_reportId].reporterAddress
            );
        }
        _queueFinishedReport(_reportId);
    }

    function reportPool(uint256 _poolId) external {
        require(!poolReported[poolAddress[_poolId]], "Pool already reported");
        require(
            IPolicyCenter(poolAddress[_poolId]) != address(0),
            "Pool doesn't exist"
        );
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

        emit ReportCreated(
            reportIds[reportCounter].reportId,
            reportIds[reportCounter].poolId,
            reportIds[reportCounter].timestamp,
            reportIds[reportCounter].reporterAddress
        );
    }

    function proposePool(
        address _protocol,
        uint256 _reinsuranceSplit,
        uint256 _insuranceSplit,
        uint256 _maxCapacity
    ) external {
        require(!poolProposed[_protocol], "Protocol already proposed");
        ++proposalCounter;
        PoolProposal proposal;
        proposal.protocolName = _protocolName;
        proposal.protocol = _protocol;
        proposal.reinsuranceSplit = _reinsuranceSplit;
        proposal.insuranceSplit = _insuranceSplit;
        proposal.maxCapacity = _maxCapacity;
        proposal.timestamp = block.timestamp;
        proposal.proposerAddress = msg.sender;
        proposal.pending = true;
        proposal.approved = false;

        proposalIds[proposalCounter] = proposal;
        emit PoolProposalCreated(
            proposalIds[proposalCounter].proposalId,
            proposalIds[proposalCounter].protocol,
            proposalIds[proposalCounter].reinsuranceSplit,
            proposalIds[proposalCounter].insuranceSplit,
            proposalIds[proposalCounter].maxCapacity,
            proposalIds[proposalCounter].timestamp,
            proposalIds[proposalCounter].proposerAddress
        );
    }

    function _queueFinishedReport(uint256 _reportId) internal {
        Report report = reportIds[_reportId];
        require(report.pending, "Report is not pending");
        require(report.approved, "Report is not approved");

        Executor(ExecutorAddress).queueReport(
            report.pending,
            report.approved,
            _reportId,
            report.poolId
        );
        reportIds[_reportId].pending = false;
    }

    function _queueNewPool(uint256 _proposalId) internal {
        PoolProposal proposal = proposalIds[_proposalId];
        require(proposal.pending, "Proposal is not pending");
        require(proposal.approved, "Proposal is not approved");

        Executor(ExecutorAddress).queuePool(
            _proposalId,
            proposal.protocolName,
            proposal.protocolAddress,
            proposal.reinsuranceSplit,
            proposal.insuranceSplit,
            proposal.maxCapacity,
            proposal.timestamp,
            proposal.proposerAddress,
            proposal.pending,
            proposal.approved
        );
        proposalIds[_proposalId].pending = false;
    }

    function liquidateAndTransferVeDEG(uint256 _reportId, bool _veredict)
        external
    {
        require(msg.sender == executorAddress, "Only Executor can liquidate");
        address[] voted = reportIds[_reportId].voted;
        for (uint256 i = 0; i < voted.length; i++) {
            if (reportIds[_reportId].confirmsReport[voted[i]] != _veredict) {
                // this would be a function on the veDEG contract that
                // takes locked veDEG and trasnfer it to proposal center contract
                IERC20(veDEG).liquidatedVeDEG(voted[i], address(this));
            }
        }
        uint256 no = reportIds[_reportId].no;
        uint256 yes = reportIds[_reportId].yes;
        // ratio is 20% of ratio of no to yes, what is commited when voting
        uint256 ratio = no / (yes * 5);
        uint256 degToTransfer = 1000;

        if (_veredict) {
            IPolictyCenter(policyCenterAddress).successfulLiquidation(
                _reportIds[_reportId].reporterAddress,
                _reportIds[_reportId].poolId
            );
            IveDEG(DEG).transfer(
                address(this),
                proposalCenterAddress,
                DEGToTransfer
            );
            ERC20(DEG).mint(reportIds[_reportId].reporterAddress, DEGToTransfer);
        }

        for (uint256 i = 0; i < voted.length; i++) {
            if (reportIds[_reportId].confirmsReport[voted[i]] == _veredict) {
                // transfers from this contract to other wallets that voted yes
                uint256 balance = IERC20(veDEG).balanceOf(voted[i]);
                IERC20(veDEG).transfer(address(this), voted[i], balance * ratio);
                if (_verdict) {
                    IERC20(veDEG).transfer(address(this), voted[i], DEGToTransfer * ratio)
                    };
            }
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
