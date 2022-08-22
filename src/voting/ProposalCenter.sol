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

import "../util/ProtocolProtection.sol";

pragma solidity ^0.8.13;

/**
 * @title Proposal Center
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the Proposal Center where users can submit reports and proposals.
 *         Each proposal and report is assigned a unique ID and is stored in the proposal center.
 *         Users can evaluate proposals and reports and vote to pass them on weighted by their veDeg balance.
 */
contract ProposalCenter is ProtocolProtection {
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
        uint256 _yes,
        uint256 _no
    );

    event PoolProposalCreated(
        uint256 indexed _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _timestamp
    );

    event PoolProposalApproved(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        uint256 _yes,
        uint256 _no
    );
    event PoolProposalRejected(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        uint256 _yes,
        uint256 _no
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(address _onboardProposal, address _incidentReport) {
        onboardProposal = _onboardProposal;
        incidentReport = _incidentReport;
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

    /**
     * @notice Returns the number of proposals in the proposal center.
     * @return PoolProposal     Pool Proposal struct with all information about a current proposal
     */
    function getPoolProposal(uint256 _proposalId)
        public
        view
        returns (IOnboardProposal.Proposal memory)
    {
        IOnboardProposal.Proposal memory proposal = IOnboardProposal(
            onboardProposal
        ).getProposal(_proposalId);

        return proposal;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Votes on currently pending report in proposal center.
     *         voting power is decided by the amount of staked veDEG.
     *         rewarded if votes with majority.
     *         punished if votes against majority.
     *
     * @param _reportId Id of the report to be voted on
     * @param _isFor    1 if "vote for", 0 if "vote against"
     * @param _amount   Amount of veDEG to be used for voting
     */

    function voteReport(
        uint256 _reportId,
        uint256 _isFor,
        uint256 _amount
    ) external {
        IIncidentReport(incidentReport).vote(
            _reportId,
            _isFor,
            _amount,
            msg.sender
        );
    }

    /**
     * @notice Votes on currently pending proposal in proposal center.
     *         voting power is decided by the amount of staked veDEG.
     *         no penalty nor rewards.
     *
     * @param _proposalId Id of the pool proposal to be voted on
     * @param _isFor      1 if "vote for", 0 if "vote against"
     * @param _amount     Amount of veDEG to be used for voting
     */
    function votePoolProposal(
        uint256 _proposalId,
        uint256 _isFor,
        uint256 _amount
    ) external {
        IOnboardProposal(onboardProposal).vote(
            _proposalId,
            _isFor,
            _amount,
            msg.sender
        );
    }

    /**
    * @notice Reports that a protocol has been compromised.
     *         user notifies that pool should be liquidated.
     *         1000 DEG tokens are held by the proposal center
     *         until report is deemed truthful.
     *
     * @param _poolId   Id of the pool to be reported
     * @param _payout   Amount of payout to be distributed if vote is truthful
     */
    function reportPool(uint256 _poolId, uint256 _payout) public {
        IIncidentReport(incidentReport).report(_poolId, _payout, msg.sender);
    }

    /**
     * @notice Proposes a new protocol to be insured.
     *
     * @param _name                Name of the protocol to be insured.
     * @param _protocolToken       Address of token to receive have a new insurance pool.
     * @param _maxCapacity         Maximum capacity of the insurance pool in native token.
     * @param _priceRatio          Price of the policy in native token.
    */
    function proposePool(
        string memory _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _priceRatio
    ) public {
        IOnboardProposal(onboardProposal).propose(
            _name,
            _protocolToken,
            _maxCapacity,
            _priceRatio,
            msg.sender
        );
    }

    /**
     * @notice Start the voting process
     *
     * @param _reportId Report id
     */
    function startReportVoting(uint256 _reportId) external {
        IIncidentReport(incidentReport).startVoting(_reportId);
    }

    /**
     * @notice Check if the proposal is settled
     *
     * @param _proposalId Proposal id
     */
    function startProposalVoting(uint256 _proposalId) external {
        IOnboardProposal(onboardProposal).startVoting(_proposalId);
    }

    /**
     * @notice Settle the final result for a report
     *
     * @param _reportId Report id
     */
    function settleReport(uint256 _reportId) external {
        IIncidentReport(incidentReport).settle(_reportId);
    }

    /**
     * @notice Settle the proposal
     *
     * @param _proposalId Proposal id
     */
    function settleProposal(uint256 _proposalId) external {
        IOnboardProposal(onboardProposal).settle(_proposalId);
    }

    /** 
     * @notice Claim reward or pay debt for a vote on a settled report.
     *
     *
     * @param _reportId Id of the report to be reward voters on.

     */
    function resolveReportVote(uint256 _reportId) external {
        IIncidentReport.UserVote memory vote = IIncidentReport(incidentReport)
            .getUserVote(msg.sender, _reportId);
        IIncidentReport.Report memory report = IIncidentReport(incidentReport)
            .getReport(_reportId);
        if (report.result == vote.choice) {
            IIncidentReport(incidentReport).claimReward(_reportId, msg.sender);
        } else {
            IIncidentReport(incidentReport).payDebt(_reportId, msg.sender);
        }
    }

    /**
     * @notice Claim back veDEG after voting result settled
     *
     * @param _proposalId Proposal id
     */
    function resolveProposalVote(uint256 _proposalId) external {
        IOnboardProposal(onboardProposal).claim(_proposalId, msg.sender);
    }
}
