// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePoolFactory {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolCreated(address poolAddress, uint256 poolId, string protocolName, address protocolToken, uint256 maxCapacity, uint256 policyPricePerShield);

    function deg() view external returns (address);
    function deployPool(string memory _name, address _protocolToken, uint256 _maxCapacity, uint256 _policyPricePerToken) external returns (address);
    function executor() view external returns (address);
    function getPoolAddressList() view external returns (address[] memory);
    function getPoolCounter() view external returns (uint256);
    function insurancePool() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function maxCapacity() view external returns (uint256);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function poolCounter() view external returns (uint256);
    function poolInfoById(uint256) view external returns (string memory protocolName, address poolAddress, address protocolToken, uint256 maxCapacity, uint256 policyPricePerShield);
    function premiumVault() view external returns (address);
    function proposalCenter() view external returns (address);
    function reinsurancePool() view external returns (address);
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
    function shield() view external returns (address);
    function transferOwnership(address newOwner) external;
    function veDeg() view external returns (address);
}
