// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePoolFactory {
<<<<<<< HEAD
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolCreated(address poolAddress, uint256 poolId, string protocolName, address protocolToken, uint256 maxCapacity, uint256 policyPricePerShield);
=======
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event PoolCreated(
        address poolAddress,
        uint256 poolId,
        string protocolName,
        address protocolToken,
        uint256 maxCapacity,
        uint256 policyPricePerShield
    );
>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb

    struct PoolInfo {
        string a;
        address b;
        address c;
        uint256 d;
        uint256 e;
    }

    function administrator() external view returns (address);

    function deg() external view returns (address);

<<<<<<< HEAD
    function administrator() view external returns (address);
    function deg() view external returns (address);
    function deployPool(string memory _name, address _protocolToken, uint256 _maxCapacity, uint256 _priceRatio) external returns (address);
    function deregisterAddress(address _tokenAddress) external;
    function executor() view external returns (address);
    function getPoolAddressList() view external returns (address[] memory);
    function getPoolCounter() view external returns (uint256);
    function getPoolInfo(uint256 _poolId) view external returns (PoolInfo memory);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function maxCapacity() view external returns (uint256);
    function onboardProposal() view external returns (address);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function poolCounter() view external returns (uint256);
    function poolInfoById(uint256) view external returns (string memory protocolName, address poolAddress, address protocolToken, uint256 maxCapacity, uint256 policyPricePerShield);
    function poolRegistered(address) view external returns (bool);
    function reinsurancePool() view external returns (address);
=======
    function deregisterAddress(address _tokenAddress) external;

    function deployPool(
        string memory _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _policyPricePerToken
    ) external returns (address);

    function executor() external view returns (address);

    function getPoolAddressList() external view returns (address[] memory);

    function getPoolInfo(uint256 _id) external view returns (PoolInfo memory);

    function incidentReport() external view returns (address);

    function insurancePoolFactory() external view returns (address);

    function maxCapacity() external view returns (uint256);

    function owner() external view returns (address);

    function policyCenter() external view returns (address);

    function poolCounter() external view returns (uint256);

    function poolInfoById(uint256)
        external
        view
        returns (
            string memory protocolName,
            address poolAddress,
            address protocolToken,
            uint256 maxCapacity,
            uint256 policyPricePerShield
        );

    function poolRegistered(address) external view returns (bool);

    function proposalCenter() external view returns (address);

    function reinsurancePool() external view returns (address);

>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
    function renounceOwnership() external;


    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setInsurancePoolFactory(address _insurancePoolFactory) external;
<<<<<<< HEAD
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
=======

    function setPolicyCenter(address _policyCenter) external;

    function setProposalCenter(address _proposalCenter) external;

>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
    function setReinsurancePool(address _reinsurancePool) external;

    function shield() external view returns (address);

    function tokenRegistered(address) external view returns (bool);

    function transferOwnership(address newOwner) external;

    function veDeg() external view returns (address);
}
