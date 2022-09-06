// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface WeightedFarmingPoolEventError {

    event PoolAdded(uint256 poolId, address token);
    event NewTokenAdded(uint256 poolId, address token, uint256 weight);
    event PoolUpdated(uint256 poolId, uint256 accRewardPerShare);
    event WeightChanged(uint256 poolId);
    event Harvest(
        uint256 poolId,
        address user,
        address receiver,
        uint256 reward
    );

    error WeightedFarmingPool__AlreadySupported();
    error WeightedFarmingPool__WrongWeightLength();
    error WeightedFarmingPool__WrongDateLength();
    error WeightedFarmingPool__ZeroAmount();
    error WeightedFarmingPool__InexistentPool();
    error WeightedFarmingPool__OnlyPolicyCenter();
    error WeightedFarmingPool__NoPendingRewards();
    error WeightedFarmingPool__NotInPool();
    error WeightedFarmingPool__ExceedsStakedAmount();
}