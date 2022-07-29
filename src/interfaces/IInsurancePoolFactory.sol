// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePoolFactory {
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

    function deg() external view returns (address);

    function deployPool(
        string memory _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _policyPricePerToken
    ) external returns (address);

    function executor() external view returns (address);

    function getPoolAddressList() external view returns (address[] memory);

    function getPoolCounter() external view returns (uint256);

    function insurancePool() external view returns (address);

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

    function premiumVault() external view returns (address);

    function proposalCenter() external view returns (address);

    function reinsurancePool() external view returns (address);

    function renounceOwnership() external;

    function setDeg(address _deg) external;

    function setExecutor(address _executor) external;

    function setInsurancePoolFactory(address _insurancePoolFactory) external;

    function setMaxCapacity(uint256 _maxCapacity) external;

    function setPolicyCenter(address _policyCenter) external;

    function setProposalCenter(address _proposalCenter) external;

    function setReinsurancePool(address _reinsurancePool) external;

    function setShield(address _shield) external;

    function setVeDeg(address _veDeg) external;

    function shield() external view returns (address);

    function transferOwnership(address newOwner) external;

    function veDeg() external view returns (address);

    function registered(address _nativeToken) external view returns (bool);
}
