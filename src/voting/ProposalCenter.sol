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
        address proposerAddress;
        address[] voted;
        uint256 maxCapacity;
        uint256 initialpolicyPricePerShield;
        uint256 timestamp;
        uint256 yes;
        uint256 no;
        bool pending;
        bool approved;
    }

    // addresses
    address public deg;
    address public veDeg;
    address public shield;
    address public insurancePoolFactory;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;

    uint256 public reportCounter;
    // refer to users who have submitted reports in here
    mapping(uint256 => Report) public reportIds;
    // reportId => address => vote
    mapping(uint256 => mapping(address => bool)) public confirmsReport;

    uint256 public proposalCounter;
    mapping(uint256 => PoolProposal) public proposalIds;
    // refer to pool addresses by accessing policy center
    mapping(address => bool) public poolReported;
    mapping(address => bool) public poolProposed;

    uint256 public reportBuffer;
    uint256 public proposalBuffer;
    // uint256[3] public voteWeights;

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
        address _reporterAddress,
        uint256 yes,
        uint256 no
    );
    event ReportRejected(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress,
        uint256 yes,
        uint256 no
    );

    event PoolProposalCreated(
        uint256 indexed _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _timestamp,
        address _proposerAddress
    );
    event PoolProposalApproved(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        address _proposerAddress,
        uint256 yes,
        uint256 no
    );
    event PoolProposalRejected(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        address _proposerAddress,
        uint256 yes,
        uint256 no
    );

    constructor() {
        reportBuffer = 3 days;
        proposalBuffer = 3 days;
    }


    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor),
            "Only owner or executor can call this function"
        );
        _;
    }

    function getReport(uint256 _reportId) public view returns ( uint256,uint256,address,uint256, uint256, bool,bool,address[] memory){
        Report memory report = reportIds[_reportId];
        return (
        report.poolId,
       report.timestamp,
       report.reporterAddress,
       report.yes,
        report.no,
        report.pending,
        report.approved,
        report.voted);
    }

    function getPoolProposal(uint256 _proposalId) public view returns (
        string memory,
        address,
        address,
        address[] memory,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        bool,
        bool
     ) {
        
            PoolProposal memory proposal = proposalIds[_proposalId];
            return (proposal.protocolName,
                    proposal.protocolAddress,
                    proposal.proposerAddress,
                    proposal.voted,
                    proposal.maxCapacity,
                    proposal.timestamp,
                    proposal.initialpolicyPricePerShield,
                    proposal.yes,
                    proposal.no,
                    proposal.pending,
                    proposal.approved);
        }

    // function setVoteWeights(uint256[3] memory _voteWeights) external onlyOwner {
    //     require(
    //         _voteWeights[0] + _voteWeights[1] + _voteWeights[2] == 10000,
    //         "vote weights must sum to 10000"
    //     );
    //     voteWeights = _voteWeights;
    // }

    function setDeg(address _deg) external onlyOwner {
        deg = _deg;
    }

    function setVeDeg(address _veDeg) external onlyOwner {
        veDeg = _veDeg;
    }

    function setShield(address _shield) external onlyOwner {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        policyCenter = _policyCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        reinsurancePool = _reinsurancePool;
    }

    function setExecutor(address _executor) external onlyOwner {
        executor = _executor;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory) external onlyOwner {
        insurancePoolFactory = _insurancePoolFactory;
    }

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

    function setBuffers(uint256 _reportBuffer, uint256 _proposalBuffer) external onlyOwnerOrExecutor {
        reportBuffer = _reportBuffer;
        proposalBuffer = _proposalBuffer;
    }

    function voteReport(uint256 _reportId, bool _vote) external {
        require(reportIds[_reportId].pending, "Report is not pending");
        address[] storage voted = reportIds[_reportId].voted;
        uint256 length = voted.length;
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "Address already voted");
        }
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // 1/5 of veDeg is locked.  lockVeDeg makes it disposable
        // IERC20(veDeg).lockVeDEG(msg.sender, balance / 5);
        if (_vote) {
            reportIds[_reportId].yes += balance;
            confirmsReport[_reportId][msg.sender] = true;
        } else {
            reportIds[_reportId].no += balance;
            confirmsReport[_reportId][msg.sender] = false;
        }
        voted.push(msg.sender);
        emit Vote(_reportId, _vote, "Report");
    }

    function votePoolProposal(uint256 _proposalId, bool _vote) external {
        require(proposalIds[_proposalId].pending, "Report is not pending");
        address[] storage voted = proposalIds[_proposalId].voted;
        uint256 length = voted.length;
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "Address already voted");
        }
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // 1/5 of veDeg is locked.  lockVeDeg makes it disposable
        // IERC20(veDeg).lockVeDEG(msg.sender, balance / 5);
        if (_vote) {
            proposalIds[_proposalId].yes += balance;
        } else {
            proposalIds[_proposalId].no += balance;
        }
        voted.push(msg.sender);
        emit Vote(_proposalId, _vote, "New Pool");
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
        require(reportIds[_reportId].timestamp + reportBuffer < block.timestamp, "report not ready");

        uint256 total = reportIds[_reportId].yes + reportIds[_reportId].no;
        require(total > IERC20(veDeg).totalSupply() / 2, "Not enough votes");
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
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
        reportIds[_reportId].pending = false;
        if (reportIds[_reportId].yes > reportIds[_reportId].no) {
            reportIds[_reportId].approved = true;
            emit ReportApproved(
                _reportId,
                reportIds[_reportId].poolId,
                reportIds[_reportId].timestamp,
                reportIds[_reportId].reporterAddress,
                reportIds[_reportId].yes,
                reportIds[_reportId].no
            );
            _queueApprovedReport(_reportId);
        } else {
            reportIds[_reportId].approved = false;
            poolReported[pool] = false;
            emit ReportRejected(
                _reportId, 
                reportIds[_reportId].poolId,
                reportIds[_reportId].timestamp,
                reportIds[_reportId].reporterAddress,
                reportIds[_reportId].yes,
                reportIds[_reportId].no
            );
        }
    }

    function evaluatePoolProposalVotes(uint256 _proposalId) external {
        require( proposalIds[_proposalId].pending, "proposal not pending");
        require(
            proposalIds[_proposalId].proposerAddress != msg.sender,
            "proposer cannot evaluate"
        );
        // 1 week for the report to be evaluated
        require( proposalIds[_proposalId].timestamp + proposalBuffer < block.timestamp, "proposal not ready");

        uint256 total = proposalIds[_proposalId].yes + proposalIds[_proposalId].no;
        require(total > IERC20(veDeg).totalSupply() / 2, "Not enough votes");
        address protocol = proposalIds[_proposalId].protocolAddress;
        // uint256 weightedComittee = (total / voteWeights[0]) * voteWeights[1];
        // uint256 weightedTeam = (total / voteWeights[0]) * voteWeights[2];
        // reportIds[_reportId].comittee
        //     ? weightedYes += weightedComittee
        //     : weightedNo += weightedComittee;
        // reportIds[_reportId].team
        //     ? weightedYes += weightedTeam
        //     : weightedNo += weightedTeam;
        proposalIds[_proposalId].pending = false;
        if (proposalIds[_proposalId].yes > proposalIds[_proposalId].no) {
            proposalIds[_proposalId].approved = true;
            
            emit PoolProposalApproved(
                _proposalId,
                protocol,
                proposalIds[_proposalId].timestamp,
                proposalIds[_proposalId].proposerAddress,
                proposalIds[_proposalId].yes,
                proposalIds[_proposalId].no
            );
            _queueAprovvedPool(_proposalId);
        } else {
            proposalIds[_proposalId].approved = false;
            poolProposed[protocol] = false;
            emit PoolProposalRejected(
                _proposalId, 
                protocol,
                proposalIds[_proposalId].timestamp,
                proposalIds[_proposalId].proposerAddress,
                proposalIds[_proposalId].yes,
                proposalIds[_proposalId].no
            );
        }
    }

    function reportPool(uint256 _poolId) public {
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            _poolId
        );
        require(!poolReported[pool], "Pool already reported");
        require(pool != address(0), "Pool doesn't exist");
        ++reportCounter;
        address[] memory initializeArray;
        poolReported[pool] = true;
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
        

        IERC20(deg).transferFrom(msg.sender, address(this), 1000);
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
        uint256 _maxCapacity,
        uint256 _initialpolicyPricePerShield
    ) public {
        require(!poolProposed[_protocol], "Protocol already proposed");
        ++proposalCounter;
        address[] memory emptyVoted;
        proposalIds[proposalCounter] = PoolProposal(
        _name,
        _protocol,
        msg.sender,
        emptyVoted,
       _maxCapacity,
        _initialpolicyPricePerShield,
        block.timestamp,
        0,
        0,
        true,
        false
        );

        poolProposed[_protocol] = true;
        emit PoolProposalCreated(
            proposalCounter,
            _protocol,
            proposalIds[proposalCounter].maxCapacity,
            proposalIds[proposalCounter].timestamp,
            proposalIds[proposalCounter].proposerAddress
        );
    }

    function _queueApprovedReport(uint256 _reportId) internal {
        Report memory report = reportIds[_reportId];
        require(report.approved, "Report is not approved");

        IExecutor(executor).queueReport(
            report.pending,
            report.approved,
            _reportId,
            report.poolId
        );
    }

    function _queueAprovvedPool(uint256 _proposalId) internal {
        PoolProposal memory proposal = proposalIds[_proposalId];
        require(proposal.approved, "Proposal is not approved");

        IExecutor(executor).queuePool(
            proposal.protocolName,
            _proposalId,
            proposal.protocolAddress,
            proposal.maxCapacity,
            proposal.timestamp,
            proposal.proposerAddress,
            proposal.pending,
            proposal.approved
        );
    }

    function liquidateAndTransferVeDEG(uint256 _reportId, bool _veredict)
        external
    {
        require(msg.sender == executor, "Only Executor can liquidate");
        address[] memory voted = reportIds[_reportId].voted;
        // for (uint256 i = 0; i < voted.length; i++) {
        //     if (confirmsReport[_reportId][voted[i]] != _veredict) {
        //         // this would be a function on the veDeg contract that
        //         // takes locked veDeg and trasnfer it to proposal center contract
        //         // IERC20(veDeg).liquidatedVeDEG(voted[i], address(this));
        //     }
        // }
        uint256 no = reportIds[_reportId].no;
        uint256 yes = reportIds[_reportId].yes;
        // ratio is 20% of ratio of no to yes, what is commited when voting
        uint256 ratio = no / (yes * 5);
        uint256 degToTransfer = 1000;

        if (_veredict) {
            IERC20(deg).transfer(proposalCenter, degToTransfer);
            IERC20(deg).transfer(
                reportIds[_reportId].reporterAddress,
                degToTransfer
            );
        }

        for (uint256 i = 0; i < voted.length; i++) {
            if (confirmsReport[_reportId][voted[i]] == _veredict) {
                // transfers from this contract to other wallets that voted yes
                uint256 balance = IERC20(veDeg).balanceOf(voted[i]);
                IERC20(veDeg).transfer(
                    voted[i],
                    balance * ratio /  IERC20(veDeg).balanceOf(address(this))
                );
                if (_veredict) {
                    IERC20(veDeg).transfer(
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
