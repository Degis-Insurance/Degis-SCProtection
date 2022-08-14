// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IProposalCenter {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event PoolProposalApproved(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        uint256 _yes,
        uint256 _no
    );
    event PoolProposalCreated(
        uint256 indexed _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _timestamp
    );
    event PoolProposalRejected(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        uint256 _yes,
        uint256 _no
    );
    event ReportApproved(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress,
        uint256 yes,
        uint256 no
    );
    event ReportCreated(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress
    );
    event ReportRejected(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress,
        uint256 _yes,
        uint256 _no
    );
    event Vote(uint256 _id, bool _quorum, string _who);

    struct Proposal {
        string a;
        address b;
        address c;
        uint256 d;
        uint256 e;
        uint256 f;
        uint256 g;
        uint256 h;
        uint256 i;
        uint256 j;
        uint256 k;
    }

    function deg() external view returns (address);

    function executor() external view returns (address);

    function getPoolProposal(uint256 _proposalId)
        external
        view
        returns (Proposal memory);

    function incidentReport() external view returns (address);

    function priorityPoolFactory() external view returns (address);

    function onboardProposal() external view returns (address);

    function owner() external view returns (address);

    function policyCenter() external view returns (address);

    function proposePool(
        string memory _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _priceRatio
    ) external;

    function protectionPool() external view returns (address);

    function renounceOwnership() external;

    function reportPool(uint256 _poolId) external;

    function setBuffers(uint256 _reportBuffer, uint256 _proposalBuffer)
        external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setPolicyCenter(address _policyCenter) external;

    function setProtectionPool(address _protectionPool) external;

    function shield() external view returns (address);

    function transferOwnership(address newOwner) external;

    function veDeg() external view returns (address);

    function votePoolProposal(
        uint256 _proposalId,
        uint256 _isFor,
        uint256 _amount
    ) external;

    function voteReport(
        uint256 _reportId,
        uint256 _isFor,
        uint256 _amount
    ) external;
}
