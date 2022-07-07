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
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IInsurancePoolFactory.sol";
import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";

pragma solidity ^0.8.13;

contract ProposalCenter is Ownable {
    struct Report {
        uint256 poolId;
        uint256 timestamp;
        address reporterAddress;
        uint256 yes;
        uint256 no;
        // bool comittee;
        // bool team;
        bool pending;
        bool approved;
        address[] voted;
    }

    struct PoolProposal {
        string protocolName;
        address protocolAddress;
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
    address public shield;
    address public insurancePoolFactory;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;
    address public premiumVault;
    address public insurancePool;

    uint256 public reportCounter;
    // refer to users who have submitted reports in here
    mapping(uint256 => Report) public reportIds;
    // reportId => address => vote
    mapping(uint256 => mapping(address => bool)) confirmsReport;

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
        address _protocol,
        uint256 _maxCapacity,
        uint256 _timestamp,
        address _proposerAddress
    );
    event PoolProposalApproved(
        uint256 _proposalId,
        uint256 _protocol,
        uint256 _timestamp,
        address _proposerAddress
    );
    event PoolProposalRejected(
        uint256 _proposalId,
        uint256 _protocol,
        uint256 _timestamp,
        address _proposerAddress
    );

    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor),
            "Only owner or executor can call this function"
        );
        _;
    }

    function getReportStartTime(uint256 _reportId) public view returns (uint256) {
        return reportIds[_reportId].timestamp;
    }

    function getReporterAddress(uint256 _reportId)
        public
        view
        returns (address)
    {
        return reportIds[_reportId].reporterAddress;
    }

    function setVoteWeights(uint256[3] memory _voteWeights) external onlyOwner {
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

    // function setCommitteeAddress(address _committeeAddress) external onlyOwner {
    //     ComitteeAddress = _committeeAddress;
    // }

    function setPoolReported(address _poolAddress, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        poolReported[_poolAddress] = _decision;
    }

    function setProposal(uint256 _proposalId, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        proposalIds[_proposalId].approved = _decision;
        proposalIds[_proposalId].pending = false;
    }

    function vote(uint256 _reportId, bool _quorum) external {
        require(reportIds[_reportId].pending, "Report is not pending");
        address[] memory voted = reportIds[_reportId].voted;
        uint256 length = voted.length;
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "You have already voted");
        }
        uint256 balance = IERC20(veDEG).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // 1/5 of veDEG is locked.  lockVeDeg makes it disposable
        // IERC20(veDEG).lockVeDEG(msg.sender, balance / 5);
        if (_quorum) {
            reportIds[_reportId].yes += balance;
            confirmsReport[_reportId][msg.sender] = true;
        } else {
            reportIds[_reportId].no += balance;
            confirmsReport[_reportId][msg.sender] = false;
        }
        reportIds[_reportId].voted.push(msg.sender);
        emit Vote(_reportId, _quorum, "veDEG");
    }

    // function comitteeVote(uint256 _reportId, bool _quorum) external {
    //     require(msg.sender == ComitteeAddress, "Only Comittee can vote");
    //     require(reportId[_reportId].pending, "Report is not pending");
    //     reportIds[_reportId].comittee = _quorum;

    //     emit Vote(_reportId, _quorum, "Comittee");
    // }

    // function teamVote(uint256 _reportId, bool _quorum) external {
    //     require(msg.sender == ComitteeAddress, "Only Comittee can vote");
    //     require(reportIds[_reportId].pending, "Report is not pending");
    //     reportIds[reportId].team = _quorum;

    //     emit Vote(_reportId, _quorum, "Team");
    // }

    function evaluateReportVotes(uint256 _reportId) external {
        require(reportIds[_reportId].pending, "report not pending");
        require(
            reportIds[_reportId].reporterAddress != msg.sender,
            "reporter cannot evaluate"
        );
        // 1 week for the report to be evaluated
        require(reportIds[_reportId].timestamp + 604800 < block.timestamp);

        uint256 weightedYes = reportIds[_reportId].yes * voteWeights[0];
        uint256 weightedNo = reportIds[_reportId].no * voteWeights[0];
        uint256 total = reportIds[_reportId].yes + reportIds[_reportId].no;
        require(total > IERC20(veDEG).totalSupply() / 2, "Not enough votes");
        address pool = IPolicyCenter(insurancePoolFactory).getInsurancePoolById(
            reportIds[_reportId].poolId
        );
        // uint256 weightedComittee = (total / voteWeights[0]) * voteWeights[1];
        // uint256 weightedTeam = (total / voteWeights[0]) * voteWeights[2];
        // reportIds[_reportId].comittee
        //     ? weightedYes += weightedComittee
        //     : weightedNo += weightedComittee;
        // reportIds[_reportId].team
        //     ? weightedYes += weightedTeam
        //     : weightedNo += weightedTeam;

        if (weightedYes > weightedNo) {
            reportIds[_reportId].approved = true;
            emit ReportApproved(
                _reportId,
                reportIds[_reportId].poolId,
                reportIds[_reportId].timestamp,
                reportIds[_reportId].reporterAddress
            );
        } else {
            reportIds[_reportId].approved = false;
            poolReported[pool] = false;
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
        address pool = IPolicyCenter(insurancePoolFactory).getInsurancePoolById(
            _poolId
        );
        require(!poolReported[pool], "Pool already reported");
        require(pool != address(0), "Pool doesn't exist");
        ++reportCounter;
        address[] memory initializeArray;
        reportIds[reportCounter] = Report(
            _poolId,
            block.timestamp,
            msg.sender,
            0,
            0,
            true,
            false,
            initializeArray
        );

        IERC20(DEG).transferFrom(msg.sender, address(this), 1000);
        IInsurancePool(pool).setPausedInsurancePool(true);
        IReinsurancePool(reinsurancePool).setPausedReinsurancePool(true);
        emit ReportCreated(
            reportCounter,
            reportIds[reportCounter].poolId,
            reportIds[reportCounter].timestamp,
            reportIds[reportCounter].reporterAddress
        );
    }

    function proposePool(
        address _protocol,
        string memory _name,
        uint256 _reinsuranceSplit,
        uint256 _insuranceSplit,
        uint256 _maxCapacity
    ) external {
        require(!poolProposed[_protocol], "Protocol already proposed");
        ++proposalCounter;
        PoolProposal memory proposal;
        proposal.protocolName = _name;
        proposal.protocolAddress = _protocol;
        proposal.reinsuranceSplit = _reinsuranceSplit;
        proposal.insuranceSplit = _insuranceSplit;
        proposal.maxCapacity = _maxCapacity;
        proposal.timestamp = block.timestamp;
        proposal.proposerAddress = msg.sender;
        proposal.pending = true;
        proposal.approved = false;

        proposalIds[proposalCounter] = proposal;
        emit PoolProposalCreated(
            proposalCounter,
            _protocol,
            proposalIds[proposalCounter].maxCapacity,
            proposalIds[proposalCounter].timestamp,
            proposalIds[proposalCounter].proposerAddress
        );
    }

    function _queueFinishedReport(uint256 _reportId) internal {
        Report memory report = reportIds[_reportId];
        require(report.pending, "Report is not pending");
        require(report.approved, "Report is not approved");

        Executor(executor).queueReport(
            report.pending,
            report.approved,
            _reportId,
            report.poolId
        );
        reportIds[_reportId].pending = false;
    }

    function _queueNewPool(uint256 _proposalId) internal {
        PoolProposal memory proposal = proposalIds[_proposalId];
        require(proposal.pending, "Proposal is not pending");
        require(proposal.approved, "Proposal is not approved");

        Executor(executor).queuePool(
            proposal.protocolName,
            _proposalId,
            proposal.protocolAddress,
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
        require(msg.sender == executor, "Only Executor can liquidate");
        address[] memory voted = reportIds[_reportId].voted;
        for (uint256 i = 0; i < voted.length; i++) {
            if (confirmsReport[_reportId][voted[i]] != _veredict) {
                // this would be a function on the veDEG contract that
                // takes locked veDEG and trasnfer it to proposal center contract
                // IERC20(veDEG).liquidatedVeDEG(voted[i], address(this));
            }
        }
        uint256 no = reportIds[_reportId].no;
        uint256 yes = reportIds[_reportId].yes;
        // ratio is 20% of ratio of no to yes, what is commited when voting
        uint256 ratio = no / (yes * 5);
        uint256 degToTransfer = 1000;

        if (_veredict) {
            IERC20(DEG).transfer(proposalCenter, degToTransfer);
            IERC20(DEG).transfer(
                reportIds[_reportId].reporterAddress,
                degToTransfer
            );
        }

        for (uint256 i = 0; i < voted.length; i++) {
            if (confirmsReport[_reportId][voted[i]] == _veredict) {
                // transfers from this contract to other wallets that voted yes
                uint256 balance = IERC20(veDEG).balanceOf(voted[i]);
                IERC20(veDEG).transfer(
                    voted[i],
                    balance * ratio /  IERC20(veDEG).balanceOf(address(this))
                );
                if (_veredict) {
                    IERC20(veDEG).transfer(
                        voted[i],
                        degToTransfer * ratio
                    );
                }
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
