// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IProposalCenter {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolProposalApproved(uint256 _proposalId, address _protocol, uint256 _timestamp, address _proposerAddress, uint256 yes, uint256 no);
    event PoolProposalCreated(uint256 indexed _proposalId, address _protocol, uint256 _maxCapacity, uint256 _timestamp, address _proposerAddress);
    event PoolProposalRejected(uint256 _proposalId, address _protocol, uint256 _timestamp, address _proposerAddress, uint256 yes, uint256 no);
    event ReportApproved(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress, uint256 yes, uint256 no);
    event ReportCreated(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress);
    event ReportRejected(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress, uint256 yes, uint256 no);
    event Vote(uint256 _id, bool _quorum, string _who);

    function confirmsReport(uint256, address) view external returns (bool);
    function deg() view external returns (address);
    function evaluatePoolProposalVotes(uint256 _proposalId) external;
    function evaluateReportVotes(uint256 _reportId) external;
    function executor() view external returns (address);
    function getPoolProposal(uint256 _proposalId) view external returns (string memory, address, address[] memory, uint256, uint256, uint256, uint256, uint256, bool, bool);
    function getReport(uint256 _reportId) view external returns (uint256, uint256, address, uint256, uint256, bool, bool, address[] memory);
    function insurancePoolFactory() view external returns (address);
    function rewardByReportId(uint256 _reportId, bool _veredict) external;
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function poolProposed(address) view external returns (bool);
    function poolReported(address) view external returns (bool);
    function proposalBuffer() view external returns (uint256);
    function proposalCenter() view external returns (address);
    function proposalCounter() view external returns (uint256);
    function proposalIds(uint256) view external returns (string memory protocolName, address protocolAddress, address proposerAddress, uint256 maxCapacity, uint256 policyPricePerShield, uint256 timestamp, uint256 yes, uint256 no, uint256 round, bool pending, bool approved);
    function proposePool(address _protocol, string memory _name, uint256 _maxCapacity, uint256 _priceRatio) external;
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
    function reportBuffer() view external returns (uint256);
    function reportCounter() view external returns (uint256);
    function reportIds(uint256) view external returns (uint256 poolId, uint256 timestamp, address reporterAddress, uint256 yes, uint256 no, uint256 round, bool pending, bool approved);
    function reportPool(uint256 _poolId) external;
    function setBuffers(uint256 _reportBuffer, uint256 _proposalBuffer) external;
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setPolicyCenter(address _policyCenter) external;
    function setPoolReported(address _poolAddress, bool _decision) external;
    function setProposal(uint256 _proposalId, bool _decision) external;
    function setProposalCenter(address _proposalCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function shield() view external returns (address);
    function transferOwnership(address newOwner) external;
    function veDeg() view external returns (address);
    function votePoolProposal(uint256 _proposalId, bool _vote) external;
    function voteReport(uint256 _reportId, bool _vote) external;
}