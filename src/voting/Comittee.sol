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

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IInsurancePool.sol";
import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";

contract Comittee is Ownable {
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

    address[] public commitee;
    address[] public team;
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
    //report id to quorum
    mapping(uint256 => mapping(address => bool)) commiteeQuorum;
    mapping(uint256 => mapping(address => bool)) teamQuorum;

    modifier onlyCommitee(uint256 _reportId) {
        bool isComittee = false;
        for (uint256 i = 0; i < commitee.length; i++) {
            if (msg.sender == commitee[i]) {
                isComittee = true;
                break;
            }
        }
        _;
    }

    modifier onlyTeam(uint256 _reportId) {
        bool isTeam = false;
        for (uint256 i = 0; i < team.length; i++) {
            if (msg.sender == team[i]) {
                isTeam = true;
                break;
            }
        }
        _;
    }

    function teamVote(uint256 _reportId, bool _vote)
        external
        onlyTeam(_reportId)
    {
        uint256 starttime = IProposalCenter(proposalCenter).getReportStartTime(
            _reportId
        );
        require(starttime < block.timestamp, "Report not found");
        teamQuorum[_reportId][msg.sender] = _vote;
    }

    function comitteeVote(uint256 _reportId, bool _vote) external onlyCommitee(_reportId) {
        uint256 starttime = IProposalCenter(proposalCenter).getReportStartTime(
            _reportId
        );
        require(starttime < block.timestamp, "Report not found");
        commiteeQuorum[_reportId][msg.sender] = _vote;
    }

    function evaluateComittee(uint256 _reportId) external onlyCommitee(_reportId) {
        uint256 starttime = IProposalCenter(proposalCenter).getReportStartTime(
            _reportId
        );
        require(starttime < block.timestamp, "Report not found");
        require(
            block.timestamp - starttime > 5 days,
            "Report not up for long enough"
        );

        uint256 totalVotes = 0;
        for (uint256 i = 0; i < commitee.length; i++) {
            if (commiteeQuorum[_reportId][commitee[i]]) {
                totalVotes++;
            }
        }
        if (totalVotes > commitee.length / 2) {
            // IProposalCenter(proposalCenter).comitteeVote(_reportId, true);
        } else {
            // IProposalCenter(proposalCenter).comitteeVote(_reportId, false);
        }
    }

    function evaluateTeam(uint256 _reportId) external onlyTeam(_reportId) {
        uint256 starttime = IProposalCenter(proposalCenter).getReportStartTime(
            _reportId
        );
        require(starttime < block.timestamp, "Report not found");
        require(
            block.timestamp - starttime > 5 days,
            "Report not up for long enough"
        );

        uint256 totalVotes = 0;
        for (uint256 i = 0; i < commitee.length; i++) {
            if (commiteeQuorum[_reportId][commitee[i]]) {
                totalVotes++;
            }
        }
        if (totalVotes > commitee.length / 2) {
            // IProposalCenter(proposalCenter).comitteeVote(_reportId, true);
        } else {
            // IProposalCenter(proposalCenter).comitteeVote(_reportId, false);
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
