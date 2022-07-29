// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../util/ProtocolProtection.sol";

import "./interfaces/IncidentReportParameters.sol";

contract IncidentReport is ProtocolProtection, IncidentReportParameters {

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Total number of reports
    uint256 public reportCounter;

    struct Report {
        uint256 poolId;
        uint256 reportTimestamp;
        address reporter;
        uint256 numFor;
        uint256 numAgainst;
        uint256 round; // 0: Initial round 3 days, 1: Extended round 1 day, 2: Double extended 1 day
        uint256 status;
        uint256 result; // 1: Pass, 2: Reject, 3: Tied
        uint256 votingReward;
    }
    // Report id => report info
    mapping(uint256 => Report) public reports;

    struct TempResult {
        uint256 result;
        uint256 sampleTimestamp;
        bool hasChanged;
    }
    mapping(uint256 => TempResult) public reportTempResults;

    struct UserVote {
        uint256 choice; // 1: vote for, 2: vote against
        uint256 amount;
        bool claimed;
    }
    // User address => report id => user's voting info
    mapping(address => mapping(uint256 => UserVote)) public userReportVotes;

    // User address => cool down for report until
    mapping(address => uint256) public userCoolDownUntil;

    // Pool address => whether the pool is being reported
    mapping(address => bool) public poolReported;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event ReportCreated(
        uint256 reportId,
        uint256 indexed poolId,
        uint256 reportTimestamp,
        address indexed reporter
    );

    event ReportVoted(
        uint256 reportId,
        address indexed user,
        uint256 voteFor,
        uint256 amount
    );

    event ReportSettled(uint256 reportId, uint256 result);

    event ReportExtended(uint256 reportId, uint256 round);

    event DebtPaid(
        address payer,
        address user,
        uint256 debt,
        uint256 unlockAmount
    );
    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    
     /**
     * @notice Returns the number of reports in the proposal center.
     * @return poolId           id of the pool the report refers to
     * @return timestamp        timestamp of the report
     * @return reporterAddress  address of the reporter
     * @return yes              number of yes votes in veDEG
     * @return no               number of no votes in veDEG
     * @return pending          if decision is still pending
     * @return approved         if current decision is approved
     * @return voted            list of addresses that have already voted
     */
    function getReport(uint256 _reportId)
        public
        view
        returns (
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256 
        )
    {
        Report memory _report = reports[_reportId];
        return (
        _report.poolId,
        _report.reportTimestamp,
        _report.reporter,
        _report.numFor,
        _report.numAgainst,
        _report.round, // 0: Initial round 3 days, 1: Extended round 1 day, 2: Double extended 1 day
        _report.status,
        _report.result, // 1: Pass, 2: Reject, 3: Tied
        _report.votingReward
        );
    }

    function getTempResult(uint256 _reportId)
        public
        view
        returns (
            uint256,
            uint256,
            bool
        )
    {
        TempResult memory _tempResult = reportTempResults[_reportId];
        return (
        _tempResult.result,
        _tempResult.sampleTimestamp,
        _tempResult.hasChanged
        );
    }

    function getUserVote(address _user, uint256 _reportId)
        public
        view
        returns (
            uint256,
            uint256,
            bool
        )
    {
        UserVote memory _vote = userReportVotes[_user][_reportId];
        return (
            _vote.choice,
            _vote.amount,
            _vote.claimed
        );
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Start a new incident report
     *
     *         1000 DEG tokens are staked to start a report
     *         If the report is correct, reporter gets back 1000DEG + 10% shield income + extra 1000DEG
     *         If the report is wrong, reporter loses 1000DEG to those who vote against
     *
     * @param _poolId Pool id to report incident
     */
    function report(uint256 _poolId) external {
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            _poolId
        );
        require(pool != address(0), "Pool doesn't exist");
        require(!poolReported[pool], "Pool already reported");

        uint256 currentReportId = ++reportCounter;

        poolReported[pool] = true;

        // Record the new report
        Report storage newReport = reports[currentReportId];
        newReport.poolId = _poolId;
        newReport.reportTimestamp = block.timestamp;
        newReport.reporter = msg.sender;
        newReport.status = PENDING_STATUS;

        // burn degis tokens to start a report
        IDegisToken(deg).burnDegis(msg.sender, REPORT_THRESHOLD);

        // Pause insurance pool and reinsurance pool
        _pausePools(pool);

        emit ReportCreated(reportCounter, _poolId, block.timestamp, msg.sender);
    }

    /**
     * @notice Vote on currently pending reports
     *
     *         Voting power is decided by the (unlocked) balance of veDEG
     *         Rewarded if votes with majority
     *         Punished if votes against majority
     *
     * @param _reportId Id of the report to be voted on
     * @param _isFor    The user's choice (1: vote for, 2: vote against)
     * @param _amount   Amount of veDEG used for this vote
     */
    function vote(
        uint256 _reportId,
        uint256 _isFor,
        uint256 _amount
    ) external {
        require(
            reports[_reportId].status == PENDING_STATUS,
            "Report is not pending status"
        );

        require(_isFor == 1 && _isFor == 2, "Wrong choice");

        // Should have enough veDEG
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender) -
            IVeDEG(veDeg).locked(msg.sender);
        require(balance >= _amount, "Not enough veDEG");

        // Lock vedeg until this report is settled
        IVeDEG(veDeg).lockVeDEG(msg.sender, _amount);

        // Record the user's choice
        UserVote storage userReportVote = userReportVotes[msg.sender][
            _reportId
        ];
        if (userReportVote.amount > 0) {
            require(
                userReportVote.choice == _isFor,
                "Can not choose both sides"
            );
        } else {
            userReportVote.choice = _isFor;
        }

        Report storage currentReport = reports[_reportId];
        // Record the vote for this report
        if (_isFor == 1) {
            currentReport.numFor += _amount;
        } else {
            currentReport.numAgainst += _amount;
        }

        // Record a temporary result
        // If the hasChanged already been true, no need for further update
        // If the voting period has passed, no need for update
        if (
            !reportTempResults[_reportId].hasChanged &&
            _notPassedVotingPeriod(
                currentReport.round,
                currentReport.reportTimestamp
            )
        ) {
            _recordTempResult(
                _reportId,
                currentReport.numFor,
                currentReport.numAgainst
            );
        }

        emit ReportVoted(_reportId, msg.sender, _isFor, _amount);
    }

    /**
     * @notice Settle the final result for a report
     *
     * @param _reportId Report id
     */
    function settle(uint256 _reportId) external {
        Report storage currentReport = reports[_reportId];

        // Check has passed the voting period
        require(
            !_notPassedVotingPeriod(
                currentReport.round,
                currentReport.reportTimestamp
            ),
            "Not reached settlement"
        );

        require(currentReport.result == 0, "Already settled");

        _checkQuorum(currentReport.numFor + currentReport.numAgainst);

        uint256 res = _checkRoundExtended(_reportId, currentReport.round);

        if (res > 0) {
            _settleVotingReward(_reportId);
            emit ReportSettled(_reportId, res);
        } else {
            emit ReportExtended(_reportId, currentReport.round);
        }
    }

    /**
     * @notice Claim the voting reward
     *
     * @param _reportId Report id
     */
    function claimReward(uint256 _reportId) external {
        UserVote memory userVote = userReportVotes[msg.sender][_reportId];
        uint256 finalResult = reports[_reportId].result;

        require(finalResult > 0, "Not settled");
        require(!userVote.claimed, "Already claimed");

        // Correct choice
        if (userVote.choice == finalResult) {
            IDegisToken(deg).mintDegis(
                msg.sender,
                (reports[_reportId].votingReward * userVote.amount) / SCALE
            );
        } else if (finalResult == TIED_RESULT) {
            // Tied result, give back user's veDEG
            IVeDEG(veDeg).unlockVeDEG(msg.sender, userVote.amount);
        } else revert("No reward to claim");

        userReportVotes[msg.sender][_reportId].claimed = true;
    }

    /**
     * @notice Pay debt to get back veDEG
     *
     *         For those who made a wrong voting choice
     *
     * @param _reportId Report id
     * @param _user     User address (can pay debt for another user)
     */
    function payDebt(uint256 _reportId, address _user) external {
        UserVote memory userVote = userReportVotes[_user][_reportId];
        uint256 finalResult = reports[_reportId].result;

        require(finalResult > 0, "Not settled");
        require(userVote.choice != finalResult, "Not wrong choice");

        uint256 debt = (userVote.amount * DEBT_RATIO) / 100;

        // Pay the debt in DEG
        IDegisToken(deg).burnDegis(msg.sender, debt);

        // Unlock the user's veDEG
        IVeDEG(veDeg).unlockVeDEG(_user, userVote.amount);

        emit DebtPaid(msg.sender, _user, debt, userVote.amount);
    }

    /**
     * @notice Settle voting reward depending on the result
     *
     * @param _reportId Report id
     */
    function _settleVotingReward(uint256 _reportId) internal {
        Report storage currentReport = reports[_reportId];

        if (currentReport.result == 1) {
            IERC20(deg).transfer(currentReport.reporter, REPORT_THRESHOLD);
            IDegisToken(deg).mintDegis(currentReport.reporter, REPORTER_REWARD);

            // Total deg reward
            uint256 totalRewardToVoters = REPORT_THRESHOLD +
                currentReport.numAgainst /
                100;

            // Update deg reward for those who vote for
            currentReport.votingReward =
                (totalRewardToVoters * SCALE) /
                currentReport.numFor;
        } else if (currentReport.result == 2) {
            // Total deg reward
            uint256 totalRewardToVoters = REPORT_THRESHOLD +
                currentReport.numFor /
                100;

            // Update deg reward for those who vote against
            currentReport.votingReward =
                (totalRewardToVoters * SCALE) /
                currentReport.numAgainst;
        }
    }

    /**
     * @notice Check quorum requirement
     *         30% of totalSupply is the minimum requirement for participation
     *
     * @param _totalVotes Total vote numbers
     */
    function _checkQuorum(uint256 _totalVotes) internal view {
        require(
            _totalVotes >= IVeDEG(veDeg).totalSupply() * QUORUM_RATIO,
            "Not reached quorum"
        );
    }

    /**
     * @notice Check whether has passed the voting time period
     *
     * @param _round      Current round
     * @param _reportTime Start timestamp of the report
     *
     * @return hasPassed True for not passing
     */
    function _notPassedVotingPeriod(uint256 _round, uint256 _reportTime)
        internal
        view
        returns (bool)
    {
        uint256 endTime = _reportTime + VOTING_PERIOD + _round * EXTEND_PERIOD;
        return block.timestamp <= endTime;
    }

    /**
     * @notice Check whether this round need extend
     *
     * @param _reportId Report id
     * @param _round    Current round
     *
     * @return result 0 for extending, 1/2/3 for final result
     */
    function _checkRoundExtended(uint256 _reportId, uint256 _round)
        internal
        returns (uint256 result)
    {
        if (!reportTempResults[_reportId].hasChanged) {
            result = _settleResult(
                _reportId,
                reports[_reportId].numFor,
                reports[_reportId].numAgainst
            );
        } else if (reportTempResults[_reportId].hasChanged && _round < 2) {
            _extendRound(_reportId);
        }
    }

    /**
     * @notice Settle the result for a report
     *
     * @param _reportId   Report id
     * @param _numFor     Number of votes voting for
     * @param _numAgainst Number of votes voting against
     *
     * @return result 0 for pass, 1 for reject and 2 for tied
     */
    function _settleResult(
        uint256 _reportId,
        uint256 _numFor,
        uint256 _numAgainst
    ) internal returns (uint256 result) {
        result = _getVotingResult(_numFor, _numAgainst);

        reports[_reportId].result = result;
    }

    /**
     * @notice Extend the current round
     *
     * @param _reportId Report id
     */
    function _extendRound(uint256 _reportId) internal {
        reports[_reportId].round += 1;
    }

    /**
     * @notice Record a temporary result when goes in the sampling period
     *
     *         Temporary result use 1 for "pass" and 2 for "reject"
     *
     * @param _reportId   Report id
     * @param _numFor     Vote numbers for
     * @param _numAgainst Vote numbers against
     */
    function _recordTempResult(
        uint256 _reportId,
        uint256 _numFor,
        uint256 _numAgainst
    ) internal {
        TempResult storage temp = reportTempResults[_reportId];

        if (
            block.timestamp >
            reports[_reportId].reportTimestamp + VOTING_PERIOD - SAMPLE_PERIOD
        ) {
            uint256 currentResult = _getVotingResult(_numFor, _numAgainst);

            // If this is the first time for sampling, not record change
            if (temp.result > 0) {
                temp.hasChanged = currentResult == temp.result;
            }

            temp.result = currentResult;
        }
    }

    /**
     * @notice Get the final voting result
     *
     * @param _numFor     Votes for
     * @param _numAgainst Votes against
     *
     * @return result Pass, reject or tied
     */
    function _getVotingResult(uint256 _numFor, uint256 _numAgainst)
        internal
        pure
        returns (uint256 result)
    {
        if (_numFor > _numAgainst) result = PASS_RESULT;
        else if (_numFor < _numAgainst) result = REJECT_RESULT;
        else result = TIED_RESULT;
    }

    /**
     * @notice Pause the related project pool and the re-insurance pool
     *         Once there is an incident reported
     *
     * @param _pool Project pool address
     */
    function _pausePools(address _pool) internal {
        IInsurancePool(_pool).setPausedInsurancePool(true);
        IReinsurancePool(reinsurancePool).setPausedReinsurancePool(true);
    }

    /**
     * @notice Pause the related project pool and the re-insurance pool
     *         Once there is an incident reported
     *
     * @param _pool Project pool address
     */
    function _unpausePools(address _pool) internal {
        IInsurancePool(_pool).setPausedInsurancePool(false);
        IReinsurancePool(reinsurancePool).setPausedReinsurancePool(false);
    }
}
