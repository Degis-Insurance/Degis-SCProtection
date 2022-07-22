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
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";
import "../util/Setters.sol";

import "../mock/MockVeDEG.sol";
import "../mock/MockDEG.sol";

pragma solidity ^0.8.13;

contract ProposalCenter is Ownable, Setters {

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    
   
    struct Report {
        uint256 poolId;
        uint256 timestamp;
        address reporterAddress;
        uint256 yes;
        uint256 no;
        uint256 round;
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
        // per year in bps 10000 == 100%
        uint256 policyPricePerShield;
        uint256 timestamp;
        uint256 yes;
        uint256 no;
        uint256 round;
        bool pending;
        bool approved;
    }

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

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    
    event Vote(uint256 _id, bool _quorum, string _who);
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

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    

    constructor() {
        reportBuffer = 3 days;
        proposalBuffer = 3 days;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor),
            "Only owner or executor can call this function"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

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
                    proposal.policyPricePerShield,
                    proposal.yes,
                    proposal.no,
                    proposal.pending,
                    proposal.approved);
        }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //
    
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

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function voteReport(uint256 _reportId, bool _vote) external {
        require(reportIds[_reportId].pending, "Report is not pending");
        address[] storage voted = reportIds[_reportId].voted;
        uint256 length = voted.length;
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "Address already voted");
        }
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        
        MockVeDEG(veDeg).lockVeDEG(msg.sender, balance / 5);
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
        // 3 days for the report to be evaluated
        require(reportIds[_reportId].timestamp + reportBuffer < block.timestamp, "report not ready");

        uint256 total = reportIds[_reportId].yes + reportIds[_reportId].no;
        require(total > IERC20(veDeg).totalSupply() / 2, "Not enough votes");
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(reportIds[_reportId].poolId);
        bool result = reportIds[_reportId].yes > reportIds[_reportId].no;
        // if last round or vote agrees with previous round, move on with the report
        if ((reportIds[_reportId].round == 2) || (reportIds[_reportId].round > 0 && result == reportIds[_reportId].approved)) {
            if (result) {
                reportIds[_reportId].approved = true;
                emit ReportApproved(
                    _reportId,
                    reportIds[_reportId].poolId,
                    reportIds[_reportId].timestamp,
                    reportIds[_reportId].reporterAddress,
                    reportIds[_reportId].yes,
                    reportIds[_reportId].no
                );
                
            IExecutor(executor).queueReport(
                reportIds[_reportId].pending,
                reportIds[_reportId].approved,
                _reportId,
                reportIds[_reportId].poolId
            );
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
            reportIds[_reportId].pending = false;
        } else {
            // if not definitive round, set approval for future check
            // and add 24hrs to voting period
            reportIds[_reportId].approved = result;
            reportIds[_reportId].timestamp += 86400;
        }
        reportIds[_reportId].round++;
    }

    function evaluatePoolProposalVotes(uint256 _proposalId) external {
        require(proposalIds[_proposalId].pending, "proposal not pending");
        // 1 week for the report to be evaluated
        require( proposalIds[_proposalId].timestamp + proposalBuffer < block.timestamp, "proposal not ready");
        address protocol = proposalIds[_proposalId].protocolAddress;
        uint256 total = proposalIds[_proposalId].yes + proposalIds[_proposalId].no;
        require(total > IERC20(veDeg).totalSupply() / 2, "Not enough votes");
        bool result = proposalIds[_proposalId].yes > proposalIds[_proposalId].no;
        if ((proposalIds[_proposalId].round == 2) || (proposalIds[_proposalId].round > 0 && result == proposalIds[_proposalId].approved)) {
            if (result) {
                proposalIds[_proposalId].approved = true;
            emit PoolProposalApproved(
                _proposalId,
                protocol,
                proposalIds[_proposalId].timestamp,
                proposalIds[_proposalId].proposerAddress,
                proposalIds[_proposalId].yes,
                proposalIds[_proposalId].no
            );
            IExecutor(executor).queuePool(
            proposalIds[_proposalId].protocolName,
            _proposalId,
            proposalIds[_proposalId].protocolAddress,
            proposalIds[_proposalId].maxCapacity,
            proposalIds[_proposalId].policyPricePerShield,
            proposalIds[_proposalId].pending,
            proposalIds[_proposalId].approved
            );
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
        proposalIds[_proposalId].pending = false;
        } else {
            // if not definitive round, set approval for future check
            // and add 24hrs to voting period
            proposalIds[_proposalId].approved = result;
            proposalIds[_proposalId].timestamp += 86400;
        }
        proposalIds[_proposalId].round++;
        
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
            0,
            true,
            false,
            initializeArray
        );
        // transfer back to deg address. another option is to burn it.
        IERC20(deg).transferFrom(msg.sender, deg, 1000);
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
        uint256 _policyPricePerShield
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
        _policyPricePerShield,
        block.timestamp,
        0,
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

    function rewardByReportId(uint256 _reportId, bool _veredict)
        external
    {
        require(msg.sender == executor, "Only Executor can liquidate");
        address[] memory voted = reportIds[_reportId].voted;
        if (_veredict) {
            IPolicyCenter(policyCenter).rewardTreasuryToReporter(reportIds[_reportId].reporterAddress);
            MockDEG(deg).mintDegis(reportIds[_reportId].reporterAddress, 2000);
        for (uint256 i = 0; i < voted.length; i++) {
            if (confirmsReport[_reportId][voted[i]] == _veredict) {
                // if voted with the decision, reward deg and unlock vedeg according to their stake
                uint256 balance = IERC20(veDeg).balanceOf(voted[i]);
                MockDEG(deg).mintDegis(voted[i], balance / 500);
                MockVeDEG(veDeg).unlockVeDEG(voted[i], balance / 5);
            }
        }
        }
    }
}
