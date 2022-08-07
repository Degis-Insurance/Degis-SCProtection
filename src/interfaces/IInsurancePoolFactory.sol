// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePoolFactory {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PoolCreated(address poolAddress, uint256 poolId, string protocolName, address protocolToken, uint256 maxCapacity, uint256 policyPricePerShield);

    struct PoolInfo { string a; address b; address c; uint256 d; uint256 e; }

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
    function renounceOwnership() external;
    function setAdministrator(address _administrator) external;
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function shield() view external returns (address);
    function tokenRegistered(address) view external returns (bool);
    function transferOwnership(address newOwner) external;
    function veDeg() view external returns (address);
}
