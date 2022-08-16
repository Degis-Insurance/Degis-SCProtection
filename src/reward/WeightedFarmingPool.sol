// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

/**
 * @notice Weighted Farming Pool
 *
 *         Weighted farming pool support multiple tokens to earn the same reward
 *         Different tokens will have different weights when calculating rewards
 *
 *
 *         Native token premiums will be transferred to this pool
 *         The distribution is in the way of "farming" but with multiple tokens
 *
 *         Different generations of PRI-LP-1-JOE-G1
 */
abstract contract WeightedFarmingPool {
    struct PoolInfo {
        address[] tokens;
        uint256[] amount;
        address rewardToken;
        uint256 rewardPerSecond;
        uint256 lastRewardTimestamp;
        uint256 accRewardPerShare;
    }
    mapping(uint256 => PoolInfo) public pools;

    mapping(bytes32 => bool) public supported;

    event NewTokenAdded(uint256 poolId, address token);

    function addPool() external {}

    function addToken(uint256 _id, address _token) external {
        bytes32 key = keccak256(abi.encodePacked(_id, _token));
        require(!supported[key], "Already supported");

        supported[key] = true;

        emit NewTokenAdded(_id, _token);
    }

    function setWeight(uint256 _id, uint256[] calldata weights) external {}

    function setSpeed(uint256 _id) external {}

    function deposit(
        uint256 _id,
        address _token,
        uint256 _amount
    ) external {}

    function withdraw(
        uint256 _id,
        address _token,
        uint256 _amount
    ) external {}

    function updatePool(uint256 _id) public {}

    function harvest(uint256 _id, address _token) external {}
}
