// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IWeightedFarmingPool {
    event Harvest(uint256 poolId, address user, address receiver, uint256 reward);
    event NewTokenAdded(uint256 poolId, address token, uint256 weight);
    event PoolAdded(uint256 poolId, address token);
    event PoolUpdated(uint256 poolId, uint256 accRewardPerShare);
    event WeightChanged(uint256 poolId);

    function BASE_WEIGHT() view external returns (uint256);
    function SCALE() view external returns (uint256);
    function addPool(address _token) external;
    function addToken(uint256 _id, address _token, uint256 _weight) external;
    function counter() view external returns (uint256);
    function estimateHarvest(uint256 _id, address _user) view external returns (uint256);
    function harvest(uint256 _id, address _to) external;
    function policyCenter() view external returns (address);
    function pools(uint256) view external returns (uint256 shares, address rewardToken, uint256 lastRewardTimestamp, uint256 accRewardPerShare);
    function premiumRewardPool() view external returns (address);
    function setPolicyCenter(address _policyCenter) external;
    function setWeight(uint256 _id, uint256[] memory weights) external;
    function deposit(uint256 _id, address _token,uint256 _amount,  address _msgsender) external;
    function supported(bytes32) view external returns (bool);
    function withdraw(uint256 _id, address _token,uint256 _amount,  address _msgsender) external;
    function updatePool(uint256 _id) external;
    function updateRewardSpeed(uint256 _id, uint256 _newSpeed, uint256[] memory _years, uint256[] memory _months) external;
    function users(uint256, address) view external returns (uint256 share, uint256 rewardDebt);
}