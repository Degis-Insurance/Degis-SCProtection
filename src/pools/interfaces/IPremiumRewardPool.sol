// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPremiumRewardPool {
    function distributeShield(uint256 _amount) external;

    function distributeToken(address _token, uint256 _amount) external;

    function register(address _pool, address _token) external;
}
