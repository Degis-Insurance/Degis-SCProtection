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
    function claim(uint256 _proposalId, address _msgsender) external;
    function closeProposal(uint256 _proposalId) external;
    function deg() view external returns (address);
    function executor() view external returns (address);
    function getProposal(uint256 _proposalId) view external returns (Proposal memory);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function onboardProposal() view external returns (address);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function poolProposed(address) view external returns (bool);
    function proposalCounter() view external returns (uint256);
    function proposals(uint256) view external returns (string memory name, address protocolToken, address proposer, uint256 proposeTimestamp, uint256 numFor, uint256 numAgainst, uint256 maxCapacity, uint256 priceRatio, uint256 poolId, uint256 status, uint256 result);
    function propose(string memory _name, address _token, uint256 _maxCapacity, uint256 _priceRatio) external;
    function propose(string memory _name, address _token, uint256 _maxCapacity, uint256 _priceRatio, address _msgsender) external;
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
<<<<<<< HEAD
    function setDeg(address _deg) external;
=======

>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
<<<<<<< HEAD
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
=======



>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
    function settle(uint256 _proposalId) external;
    function shield() view external returns (address);
    function startVoting(uint256 _proposalId) external;
    function transferOwnership(address newOwner) external;
    function userProposalVotes(address, uint256) view external returns (uint256 choice, uint256 amount, bool claimed);
    function veDeg() view external returns (address);
    function vote(uint256 _proposalId, uint256 _isFor, uint256 _amount) external;
    function vote(uint256 _reportId, uint256 _isFor, uint256 _amount, address _msgsender) external;
}
