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

import "./ProposalCenter.sol";

contract Comittee {

    address[] public commitee;
    address[] public team;
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

    function teamVote(uint256 _reportId, bool _vote) external onlyTeam {
        require(ProposalCenter.reportIds[_reportId] != 0, "Report not found");
        teamQuorum[_reportId][msg.sender] = _vote;
    }

    function comitteeVote(uint256 _reportId, bool _vote) external onlyCommitee {
        require(ProposalCenter.reportIds[_reportId] != 0, "Report not found");
        commiteeQuorum[_reportId][msg.sender] = _vote;
    }

    function evaluateComittee(uint256 _reportId) external onlyCommitee {
        require(ProposalCenter.reportIds[_reportId] != 0, "Report not found");
        require(block.timestamp - ProposalCenter.reportIds[_reportId].timestamp > 5 days, "Report not up for long enough");
        
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < commitee.length; i++) {
            if (commiteeQuorum[_reportId][commitee[i]]) {
                totalVotes++;
            }
        }
        if (totalVotes > commitee.length / 2) {
            ProposalCenter.comitteeVote(_reportId, true);
        } else {
            ProposalCenter.comitteeVote(_reportId, false);
        }
    }

    function evaluateTeam(uint256 _reportId) external onlyTeam {
        require(ProposalCenter.reportIds[_reportId] != 0, "Report not found");
        require(block.timestamp - ProposalCenter.reportIds[_reportId].timestamp  > 5 days, "Report not up for long enough");
        
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < commitee.length; i++) {
            if (commiteeQuorum[_reportId][commitee[i]]) {
                totalVotes++;
            }
        }
        if (totalVotes > commitee.length / 2) {
            IProposalCenter(proposalCenterAddress).comitteeVote(_reportId, true);
        } else {
            IProposalCenter(proposalCenterAddress).comitteeVote(_reportId, false);
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