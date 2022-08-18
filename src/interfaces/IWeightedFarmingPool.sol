// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IWeightedFarmingPool {
    function updateRewardSpeed(
        uint256 _id,
        uint256 _newSpeed,
        uint256[] memory _years,
        uint256[] memory _months
    ) external;
}
