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
    event NewProposal(
        string name,
        address token,
        uint256 maxCapacity,
        uint256 priceRatio
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event ProposalSettled(uint256 proposalId, uint256 result);
    event ProposalVoted(
        uint256 proposalId,
        address indexed user,
        uint256 voteFor,
        uint256 amount
    );

    function claim(uint256 _proposalId) external;

    function claim(uint256 _proposalId, address _msgsender) external;

    function closeProposal(uint256 _proposalId) external;

    function deg() external view returns (address);

    function executor() external view returns (address);

    function getProposal(uint256 _proposalId)
        external
        view
        returns (Proposal memory);

    function incidentReport() external view returns (address);

    function priorityPoolFactory() external view returns (address);

    function onboardProposal() external view returns (address);

    function owner() external view returns (address);

    function policyCenter() external view returns (address);

    function poolProposed(address) external view returns (bool);

    function proposalCounter() external view returns (uint256);

    function proposals(uint256)
        external
        view
        returns (
            string memory name,
            address protocolToken,
            address proposer,
            uint256 proposeTimestamp,
            uint256 numFor,
            uint256 numAgainst,
            uint256 maxCapacity,
            uint256 priceRatio,
            uint256 poolId,
            uint256 status,
            uint256 result
        );

    function propose(
        string memory _name,
        address _token,
        uint256 _maxCapacity,
        uint256 _priceRatio
    ) external;

    function propose(
        string memory _name,
        address _token,
        uint256 _maxCapacity,
        uint256 _priceRatio,
        address _msgsender
    ) external;

    function protectionPool() external view returns (address);

    function renounceOwnership() external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setPolicyCenter(address _policyCenter) external;

    function setProtectionPool(address _protectionPool) external;

    function settle(uint256 _proposalId) external;

    function shield() external view returns (address);

    function startVoting(uint256 _proposalId) external;

    function transferOwnership(address newOwner) external;

    function getUserProposalVote(address user, uint256 proposalId)
        external
        view
        returns (uint256 choice);

    function veDeg() external view returns (address);

    function vote(
        uint256 _proposalId,
        uint256 _isFor,
        uint256 _amount
    ) external;

    function vote(
        uint256 _reportId,
        uint256 _isFor,
        uint256 _amount,
        address _msgsender
    ) external;
}
