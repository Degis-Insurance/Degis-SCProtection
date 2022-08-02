// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IIncidentReport {
    event DebtPaid(address payer, address user, uint256 debt, uint256 unlockAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReportClosed(uint256 reportId, uint256 closeTimestamp);
    event ReportCreated(uint256 reportId, uint256 indexed poolId, uint256 reportTimestamp, address indexed reporter);
    event ReportExtended(uint256 reportId, uint256 round);
    event ReportSettled(uint256 reportId, uint256 result);
    event ReportVoted(uint256 reportId, address indexed user, uint256 voteFor, uint256 amount);
    event VotingStart(uint256 reportId, uint256 startTimestamp);

    struct TempResult { uint256 a; uint256 b; bool c; }
    struct UserVote { uint256 a; uint256 b; bool c; }
    struct Report { uint256 a; uint256 b; address c; uint256 d; uint256 e; uint256 f; uint256 g; uint256 h; uint256 i; uint256 j; }

    function COOLDOWN_WRONGREPORT() view external returns (uint256);
    function claimReward(uint256 _reportId) external;
    function closeReport(uint256 _reportId) external;
    function deg() view external returns (address);
    function executor() view external returns (address);
    function getReport(uint256 _id) view external returns (Report memory);
    function getTempResult(uint256 _id) view external returns (TempResult memory);
    function getUserVote(address _user, uint256 _id) view external returns (UserVote memory);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function owner() view external returns (address);
    function payDebt(uint256 _reportId, address _user) external;
    function policyCenter() view external returns (address);
    function poolReported(address) view external returns (bool);
    function proposalCenter() view external returns (address);
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
    function report(uint256 _poolId) external;
    function reportCounter() view external returns (uint256);
    function reportTempResults(uint256) view external returns (uint256 result, uint256 sampleTimestamp, bool hasChanged);
    function reports(uint256) view external returns (uint256 poolId, uint256 reportTimestamp, address reporter, uint256 voteTimestamp, uint256 numFor, uint256 numAgainst, uint256 round, uint256 status, uint256 result, uint256 votingReward);
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setPolicyCenter(address _policyCenter) external;
    function setProposalCenter(address _proposalCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function settle(uint256 _reportId) external;
    function shield() view external returns (address);
    function startVoting(uint256 _reportId) external;
    function transferOwnership(address newOwner) external;
    function userCoolDownUntil(address) view external returns (uint256);
    function userReportVotes(address, uint256) view external returns (uint256 choice, uint256 amount, bool claimed);
    function veDeg() view external returns (address);
    function vote(uint256 _reportId, uint256 _isFor, uint256 _amount) external;
}