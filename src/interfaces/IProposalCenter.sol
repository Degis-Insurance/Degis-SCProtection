// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IProposalCenter {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolProposalApproved(uint256 _proposalId, address _protocol, uint256 _timestamp, uint256 _yes, uint256 _no);
    event PoolProposalCreated(uint256 indexed _proposalId, address _protocol, uint256 _maxCapacity, uint256 _timestamp);
    event PoolProposalRejected(uint256 _proposalId, address _protocol, uint256 _timestamp, uint256 _yes, uint256 _no);
    event ReportApproved(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress, uint256 yes, uint256 no);
    event ReportCreated(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress);
    event ReportRejected(uint256 _reportId, uint256 _poolId, uint256 _timestamp, address _reporterAddress, uint256 _yes, uint256 _no);
    event Vote(uint256 _id, bool _quorum, string _who);

    struct Proposal { string a; address b; address c; uint256 d; uint256 e; uint256 f; uint256 g; uint256 h; uint256 i; uint256 j; uint256 k; }

    function deg() view external returns (address);
    function executor() view external returns (address);
    function getPoolProposal(uint256 _proposalId) view external returns (Proposal memory);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function onboardProposal() view external returns (address);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function proposePool(string memory _name, address _protocolToken, uint256 _maxCapacity, uint256 _priceRatio) external;
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
    function reportPool(uint256 _poolId) external;
<<<<<<< HEAD
    function rewardByReportId(uint256 _reportId, bool _vote) external;
    function setDeg(address _deg) external;
=======
    function setBuffers(uint256 _reportBuffer, uint256 _proposalBuffer) external;
  
>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
   
    function shield() view external returns (address);
    function transferOwnership(address newOwner) external;
    function veDeg() view external returns (address);
    function votePoolProposal(uint256 _proposalId, uint256 _isFor, uint256 _amount) external;
    function voteReport(uint256 _reportId, uint256 _isFor, uint256 _amount) external;
}