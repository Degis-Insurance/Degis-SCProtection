// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPayoutPool.sol";

interface IFactory {
    function dynamicPoolCounter() external view returns (uint256);

    function updateMaxCapacity(bool _isUp, uint256 _maxCapacity) external;

    function updateDynamicPool(uint256 _poolId) external;

    function executor() external view returns (address);
}

interface ISimpleProtectionPool {
    function getTotalCovered() external view returns (uint256);

    function getLatestPrice() external returns (uint256);

    function removedLiquidity(uint256 _amount, address _provider)
        external
        returns (uint256);

    function removedLiquidityWhenClaimed(uint256 _amount, address _to) external;

    function pauseProtectionPool(bool _paused) external;
}

interface ISimpleWeightedFarmingPool {
    function addPool(address _token) external;

    function addToken(
        uint256 _id,
        address _token,
        uint256 _weight
    ) external;

    function updateRewardSpeed(
        uint256 _id,
        uint256 _newSpeed,
        uint256[] memory _years,
        uint256[] memory _months
    ) external;

    function updateWeight(
        uint256 _id,
        address _token,
        uint256 _newWeight
    ) external;
}

interface ISimplePolicyCenter {
    function storePoolInformation(
        address _pool,
        address _token,
        uint256 _poolId
    ) external;
}

abstract contract PriorityPoolDependencies {
    uint256 constant SCALE = 1e12;

    uint256 constant SECONDS_PER_YEAR = 86400 * 365;

    address internal policyCenter;
    address internal priorityPoolFactory;
    address internal protectionPool;
    address internal weightedFarmingPool;
    address internal payoutPool;
}
