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

import "../../util/OwnableWithoutContext.sol";

import "./IncidentReportParameters.sol";
import "./IncidentReportDependencies.sol";
import "./IncidentReportErrorEvent.sol";

import "../../interfaces/ExternalTokenDependencies.sol";

import "forge-std/console.sol";

/**
 * @notice Incident Report Contract
 *
 *         New reports for project hacks are handled inside this contract
 *
 *         Timeline for a report is:
 *
 *         |-----------------------|----------------------|-------|-------|
 *               Pending Period         Voting Period       Extend Period
 *
 *         When a new report is proposed, it start with PENDING_STATUS.
 *         The person who start the report need to deposit REPORT_THRESHOLD DEG tokens.
 *         During PENDING_STATUS, users & security companies can look at the report event.
 *
 *         After PENDING_PERIOD, the voting can be started and status transfer to VOTING_STATUS.
 *         Users can vote for or against the report with veDeg tokens.
 *         VeDeg tokens used for voting will be tentatively locked until the voting is settled.
 *
 *         After VOTING_PERIOD, the voting can be settled and status transfer to SETTLED_STATUS.
 *         Depending on the votes of each side, the result can be PASSED, REJECTED or TIED.
 *         Different results for their veDeg tokens will be set depending on the result.
 *
 *         If the result has changes during the last 24 hours of voting, the voting will be extended.
 *         The time can only be extended twice.
 *
 *         For voters:
 *              PASSED: Who vote for will get all veDeg tokens from the opposite side
 *              REJECTED: Who vote against will get all veDeg tokens from the opposite side
 *              TIED: Users can unlock their veDeg tokens
 *         For reporter:
 *              PASSED: Get back REPORT_THRESHOLD and get extra REPORT_REWARD & 10% of total treasury income
 *              REJECTED: Lose REPORT_THRESHOLD to whom vote against
 *              TIED: Lose REPORT_THRESHOLD
 */
contract IncidentReport is
    IncidentReportParameters,
    IncidentReportEventError,
    ExternalTokenDependencies,
    OwnableWithoutContext,
    IncidentReportDependencies
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public proposalCenter;
    // Total number of reports
    uint256 public reportCounter;

    struct Report {
        uint256 poolId; // Project pool id
        uint256 reportTimestamp; // Time of starting report
        address reporter; // Reporter address
        uint256 voteTimestamp; // Voting start timestamp
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 round; // 0: Initial round 3 days, 1: Extended round 1 day, 2: Double extended 1 day
        uint256 status; // PENDING, VOTING, SETTLED, CLOSED
        uint256 result; // 1: Pass, 2: Reject, 3: Tied
        uint256 votingReward; // Voting reward per veDEG
    }
    // Report id => Report
    mapping(uint256 => Report) public reports;

    struct TempResult {
        uint256 result;
        uint256 sampleTimestamp;
        bool hasChanged;
    }
    mapping(uint256 => TempResult) public tempResults;

    struct UserVote {
        uint256 choice; // 1: vote for, 2: vote against
        uint256 amount; // total veDEG amount for voting
        bool claimed; // whether has claimed the reward
    }
    // User address => report id => user's voting info
    mapping(address => mapping(uint256 => UserVote)) public votes;

    // User address => cool down for report until
    mapping(address => uint256) public userCoolDownUntil;

    // Pool address => whether the pool is being reported
    mapping(address => bool) public reported;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    constructor(
        address _deg,
        address _veDeg,
        address _shield
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {}

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function getUserVote(address _user, uint256 _poolId)
        external
        view
        returns (UserVote memory)
    {
        return votes[_user][_poolId];
    }

    function getTempResult(uint256 _poolId)
        external
        view
        returns (TempResult memory)
    {
        return tempResults[_poolId];
    }

    function getReport(uint256 _id) public view returns (Report memory) {
        return reports[_id];
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        _setPolicyCenter(_policyCenter);
    }

    function setProtectionPool(address _protectionPool) external onlyOwner {
        _setProtectionPool(_protectionPool);
    }

    function setInsurancePoolFactory(address _insurancePoolFactory)
        external
        onlyOwner
    {
        _setInsurancePoolFactory(_insurancePoolFactory);
    }

    function setProposalCenter(address _proposalCenter) external onlyOwner {
        proposalCenter = _proposalCenter;
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
        // Check pool can be reported
        address pool = _checkPoolStatus(_poolId);

        // Mark as already reported
        reported[pool] = true;

        uint256 currentReportId = ++reportCounter;
        // Record the new report
        Report storage newReport = reports[currentReportId];
        newReport.poolId = _poolId;
        newReport.reportTimestamp = block.timestamp;
        newReport.reporter = msg.sender;
        newReport.status = PENDING_STATUS;

        // Burn degis tokens to start a report
        // Need to add this smart contract to burner list
        IDegisToken(deg).burnDegis(msg.sender, REPORT_THRESHOLD);

        emit ReportCreated(reportCounter, _poolId, block.timestamp, msg.sender);
    }

    /**
     * @notice Start the voting process
     *
     *         Can only be started after the pending period
     *         Will change the status from PENDING to VOTING
     *
     * @param _reportId Report id
     */
    function startVoting(uint256 _reportId) external {
        Report storage currentReport = reports[_reportId];
        require(currentReport.status == PENDING_STATUS, "Not pending status");

        // Can only start the voting after pending period
        require(
            _passedPendingPeriod(currentReport.reportTimestamp),
            "Not passed pending period"
        );

        currentReport.status = VOTING_STATUS;
        currentReport.voteTimestamp = block.timestamp;

        // Pause insurance pool and reinsurance pool
        _pausePools(pool);

        emit VotingStart(_reportId, block.timestamp);
    }

    /**
     * @notice Close a pending report
     *
     *         Can only be started after the pending period
     *         Will change the status from PENDING to CLOSED
     *
     * @param _reportId Report id
     */
    function closeReport(uint256 _reportId) external onlyOwner {
        Report storage currentReport = reports[_reportId];
        require(currentReport.status == PENDING_STATUS, "Not pending status");

        // Must close the report before pending period ends
        require(
            !_passedPendingPeriod(currentReport.reportTimestamp),
            "Already passed pending period"
        );

        currentReport.status = CLOSE_STATUS;

        emit ReportClosed(_reportId, block.timestamp);
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
        // Should be manually switched on the voting process
        require(
            reports[_reportId].status == VOTING_STATUS,
            "Not voting status"
        );

        require(_isFor == 1 || _isFor == 2, "Wrong choice");

        _enoughVeDEG(msg.sender, _amount);

        // Lock vedeg until this report is settled
        IVeDEG(veDeg).lockVeDEG(msg.sender, _amount);

        // Record the user's choice
        UserVote storage userReportVote = votes[msg.sender][_reportId];
        if (userReportVote.amount > 0) {
            require(
                userReportVote.choice == _isFor,
                "Can not choose both sides"
            );
        } else {
            userReportVote.choice = _isFor;
        }

        userReportVote.amount += _amount;

        Report storage currentReport = reports[_reportId];
        // Record the vote for this report
        if (_isFor == 1) {
            currentReport.numFor += _amount;
        } else {
            currentReport.numAgainst += _amount;
        }

        // Record a temporary result
        // If the hasChanged already been true, no need for further update
        // If not reached the last day, no need for update
        if (
            !tempResults[_reportId].hasChanged &&
            _withinLastDay(currentReport.voteTimestamp, currentReport.round)
        ) {
            _recordTempResult(
                _reportId,
                currentReport.round,
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

        require(currentReport.status == VOTING_STATUS, "Not voting status");

        // Check has passed the voting period
        require(
            _passedVotingPeriod(
                currentReport.round,
                currentReport.voteTimestamp
            ),
            "Not reached settlement"
        );

        require(currentReport.result == 0, "Already settled");

        _checkQuorum(currentReport.numFor + currentReport.numAgainst);

        uint256 res = _checkRoundExtended(_reportId, currentReport.round);

        if (res > 0) {
            _settleVotingReward(_reportId);

            currentReport.status = SETTLED_STATUS;

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
        UserVote memory userVote = votes[msg.sender][_reportId];
        uint256 finalResult = reports[_reportId].result;

        require(finalResult > 0, "Not settled");
        require(!userVote.claimed, "Already claimed");

        // Correct choice
        if (userVote.choice == finalResult) {
            IDegisToken(deg).mintDegis(
                msg.sender,
                (reports[_reportId].votingReward * userVote.amount) / SCALE
            );
            IVeDEG(veDeg).unlockVeDEG(msg.sender, userVote.amount);
        } else if (finalResult == TIED_RESULT) {
            // Tied result, give back user's veDEG
            IVeDEG(veDeg).unlockVeDEG(msg.sender, userVote.amount);
        } else revert("No reward to claim");

        votes[msg.sender][_reportId].claimed = true;
    }

    /**
     * @notice Pay debt to get back veDEG
     *
     *         For those who made a wrong voting choice
     *         The paid DEG will be burned and the veDEG will be unlocked
     *
     * @param _reportId Report id
     * @param _user     User address (can pay debt for another user)
     */
    function payDebt(uint256 _reportId, address _user) external {
        UserVote memory userVote = votes[_user][_reportId];
        uint256 finalResult = reports[_reportId].result;

        require(finalResult > 0, "Not settled");
        require(userVote.choice != finalResult, "Not wrong choice");

        uint256 debt = (userVote.amount * DEBT_RATIO) / 10000;

        // Pay the debt in DEG
        IDegisToken(deg).burnDegis(msg.sender, debt);

        // Unlock the user's veDEG
        IVeDEG(veDeg).unlockVeDEG(_user, userVote.amount);

        emit DebtPaid(msg.sender, _user, debt, userVote.amount);
    }

    function unpausePools(address _pool) external {
        require(
            IInsurancePool(_pool).endLiquidationDate() < block.timestamp,
            "pool is still in payout period"
        );
        _unpausePools(_pool);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Settle voting reward depending on the result
     *
     * @param _reportId Report id
     */
    function _settleVotingReward(uint256 _reportId) internal {
        Report storage currentReport = reports[_reportId];

        if (currentReport.result == 1) {
            // Get back REPORT_THRESHOLD and get extra REPORTER_REWARD deg tokens
            IDegisToken(deg).mintDegis(
                currentReport.reporter,
                REPORTER_REWARD + REPORT_THRESHOLD
            );

            // Total deg reward
            uint256 totalRewardToVoters = currentReport.numAgainst / 100;

            // Update deg reward for those who vote for
            currentReport.votingReward =
                (totalRewardToVoters * SCALE) /
                currentReport.numFor;
        } else if (currentReport.result == 2) {
            // Total deg reward = reporter's DEG + those who vote for
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
            _totalVotes >= (IVeDEG(veDeg).totalSupply() * QUORUM_RATIO) / 100,
            "Not reached quorum"
        );
    }

    /**
     * @notice Check veDEG to be enough
     *
     * @param _user   User address
     * @param _amount Amount to fulfill
     */
    function _enoughVeDEG(address _user, uint256 _amount) internal view {
        uint256 unlockedBalance = IERC20(veDeg).balanceOf(_user) -
            IVeDEG(veDeg).locked(_user);
        require(unlockedBalance >= _amount, "Not enough veDEG");
    }

    /**
     * @notice Check whether has passed the pending time period
     *
     * @param _reportTimestamp Start timestamp of the report
     *
     * @return hasPassed True for passing
     */
    function _passedPendingPeriod(uint256 _reportTimestamp)
        internal
        view
        returns (bool)
    {
        return block.timestamp > _reportTimestamp + PENDING_PERIOD;
    }

    /**
     * @notice Check whether has passed the voting time period
     *
     * @param _round      Current round
     * @param _reportTime Start timestamp of the report
     *
     * @return hasPassed True for passing
     */
    function _passedVotingPeriod(uint256 _round, uint256 _voteTimestamp)
        internal
        view
        returns (bool)
    {
        uint256 endTime = _voteTimestamp +
            VOTING_PERIOD +
            _round *
            EXTEND_PERIOD;
        return block.timestamp > endTime;
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
        if (!tempResults[_reportId].hasChanged) {
            result = _settleResult(
                _reportId,
                reports[_reportId].numFor,
                reports[_reportId].numAgainst
            );
        } else if (tempResults[_reportId].hasChanged && _round < 2) {
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
     * @param _round      Current voting round
     * @param _numFor     Vote numbers for
     * @param _numAgainst Vote numbers against
     */
    function _recordTempResult(
        uint256 _reportId,
        uint256 _round,
        uint256 _numFor,
        uint256 _numAgainst
    ) internal {
        TempResult storage temp = tempResults[_reportId];

        // Only record when it has reached the last day (time uint)

        uint256 currentResult = _getVotingResult(_numFor, _numAgainst);

        // If this is the first time for sampling, not record hasChange state
        if (temp.result > 0) {
            temp.hasChanged = currentResult != temp.result;
        }

        // Store the current result and sample time
        temp.result = currentResult;
        temp.sampleTimestamp = block.timestamp;
    }

    /**
     * @notice Check time is within the last day
     *
     * @param _voteTimestamp Vote start timestamp
     * @param _round         Current round
     */
    function _withinLastDay(uint256 _voteTimestamp, uint256 _round) internal {
        uint256 endTime = _voteTimestamp +
            VOTING_PERIOD +
            _round *
            EXTEND_PERIOD;

        uint256 lastDayStart = _voteTimestamp +
            VOTING_PERIOD +
            _round *
            EXTEND_PERIOD -
            SAMPLE_PERIOD;

        return block.timstamp > lastDayStart && block.timestamp < endTime;
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
     * @notice Check pool status and return address
     *         Ensure the pool exists and has not been reported
     *
     * @param _poolId Pool id
     *
     * @return poolAddress Pool address
     */
    function _checkPoolStatus(uint256 _poolId)
        internal
        view
        returns (address pool)
    {
        pool = IPolicyCenter(policyCenter).insurancePools(_poolId);
        require(pool != address(0), "Pool doesn't exist");
        require(!reported[pool], "Pool already reported");
    }

    /**
     * @notice Pause the related project pool
     *         Once there is an incident reported and voting start
     *         If the vote is closed or
     *
     * @param _pool Project pool address
     */
    function _pausePools(address _pool) internal {
        IInsurancePool(_pool).pauseInsurancePool(true);
    }

    /**
     * @notice Pause the related project pool and the re-insurance pool
     *         Once there is an incident reported
     *
     * @param _pool Project pool address
     */
    function _unpausePools(address _pool) internal {
        IInsurancePool(_pool).pauseInsurancePool(false);
    }
}
