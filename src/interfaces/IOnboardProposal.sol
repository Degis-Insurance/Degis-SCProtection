// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IOnboardProposal {

    struct Proposal {
        string name;
        address protocolAddress;
        address proposer;
        uint256 proposeTimestamp;
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 maxCapacity;
        uint256 priceRatio;
        uint256 poolId;
        uint256 status;
        uint256 result;
    }

    event NewProposal(string name, address token, uint256 maxCapacity, uint256 priceRatio);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProposalSettled(uint256 proposalId, uint256 result);
    event ProposalVoted(uint256 proposalId, address indexed user, uint256 voteFor, uint256 amount);

    function claim(uint256 _proposalId) external;
    function deg() view external returns (address);
    function executor() view external returns (address);
    function executeProposal(uint256 _proposalId) external returns (address);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function getProposal(uint256 _proposalId) external view returns (string memory, address, uint256, uint256, uint256, uint256);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function proposalCenter() view external returns (address);
    function proposalCounter() view external returns (uint256);
    function proposals(uint256) view external returns (string memory name,address protocolAddress, address proposer,uint256 proposeTimestamp, uint256 numFor, uint256 numAgainst, uint256 maxCapacity, uint256 priceRatio, uint256 poolId, uint256 status, uint256 result);
    function propose(string memory _name, address _token, uint256 _maxCapacity, uint256 _priceRatio) external;
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setPolicyCenter(address _policyCenter) external;
    function setProposalCenter(address _proposalCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function settle(uint256 _proposalId) external;
    function shield() view external returns (address);
    function transferOwnership(address newOwner) external;
    function userProposalVotes(address, uint256) view external returns (uint256 choice, uint256 amount, bool claimed);
    function veDeg() view external returns (address);
    function vote(uint256 _proposalId, uint256 _isFor, uint256 _amount) external;
}