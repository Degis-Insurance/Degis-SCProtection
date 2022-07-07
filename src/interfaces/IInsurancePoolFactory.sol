// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePoolFactory {
    struct PoolInfo {
        string protocolName;
        address poolAddress;
        address protocolToken;
        uint256 vaultSplit;
        uint256 treasurySplit;
        uint256 maxCapacity;
    }

    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity
    ) external;

    function getPoolList() external view returns (PoolInfo[] memory list);

    function getPoolCounter() external view returns (uint256);
}
