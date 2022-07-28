// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IVeDEG.sol";

import "./interfaces/IncidentReportParameters.sol";

contract IncidentReport is IncidentReportParameters {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // DEG token address
    address public DEG;

    // VeDEG token address
    address public veDEG;

    // Policy center address
    address public policyCenter;

    // ReInsurancePool address
    address public reInsurancePool;

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
        bool choice;
        uint256 amount;
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
        bool voteFor,
        uint256 amount
    );

    event ReportSettled(uint256 reportId, uint256 result);

    event ReportExtended(uint256 reportId, uint256 round);

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
    function report(uint256 _poolId) public {
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

        // transfer back to deg address. another option is to burn it.
        IERC20(DEG).transferFrom(msg.sender, address(this), 1000);

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
     * @param _isFor    The user's choice (0: vote for, 1: vote against)
     * @param _amount   Amount of veDEG used for this vote
     */
    function vote(
        uint256 _reportId,
        bool _isFor,
        uint256 _amount
    ) external {
        require(
            reports[_reportId].status == PENDING_STATUS,
            "Report is not pending status"
        );

        // Should have enough veDEG
        uint256 balance = IERC20(veDEG).balanceOf(msg.sender) -
            IVeDEG(veDEG).locked(msg.sender);
        require(balance >= _amount, "Not enough veDEG");

        // Lock vedeg until this report is settled
        IVeDEG(veDEG).lockVeDEG(msg.sender, _amount);

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
        if (_isFor) {
            currentReport.numFor += _amount;
        } else {
            currentReport.numAgainst += _amount;
        }

        // Record a temporary result
        if (
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

        _checkQuorum(currentReport.numFor + currentReport.numAgainst);

        uint256 res = _checkRoundExtended(_reportId, currentReport.round);

        if (res > 0) {
            emit ReportSettled(_reportId, res);
        } else {
            emit ReportExtended(_reportId, currentReport.round);
        }
    }

    function _checkQuorum(uint256 _totalVotes) internal {
        require(
            _totalVotes >= IVeDEG(veDEG).totalSupply() * QUORUM_RATIO,
            "Not reached quorum"
        );
    }

    function _notPassedVotingPeriod(uint256 _round, uint256 _reportTime)
        internal
        view
        returns (bool)
    {
        uint256 endTime = _reportTime + VOTING_PERIOD + _round * EXTEND_PERIOD;
        return block.timestamp <= endTime;
    }

    function _checkRoundExtended(uint256 _reportId, uint256 _round)
        internal
        returns (uint256)
    {
        if (!reportTempResults[_reportId].hasChanged) {
            return
                _settleResult(
                    _reportId,
                    reports[_reportId].numFor,
                    reports[_reportId].numAgainst
                );
        } else if (reportTempResults[_reportId].hasChanged && _round < 2) {
            _extendRound(_reportId);
            return 0;
        }
    }

    function _settleResult(
        uint256 _reportId,
        uint256 _numFor,
        uint256 _numAgainst
    ) internal returns (uint256) {
        if (_numFor > _numAgainst) {
            reports[_reportId].result = PASS_RESULT;
            return PASS_RESULT;
        } else if (_numFor < _numAgainst) {
            reports[_reportId].result = REJECT_RESULT;
            return REJECT_RESULT;
        } else {
            reports[_reportId].result = TIED_RESULT;
            return TIED_RESULT;
        }
    }

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
            uint256 currentResult = _numFor > _numAgainst ? 1 : 2;

            // If this is the first time goes in sample period, not record change
            if (temp.result > 0) {
                temp.hasChanged = currentResult == temp.result;
            }

            temp.result = currentResult;
        }
    }

    /**
     * @notice Pause the related project pool and the re-insurance pool
     *         Once there is an incident reported
     *
     * @param _pool Project pool address
     */
    function _pausePools(address _pool) internal {
        IInsurancePool(_pool).setPausedInsurancePool(true);
        IReinsurancePool(reInsurancePool).setPausedReinsurancePool(true);
    }

    function _unpausePools(address _pool) internal {}
}
