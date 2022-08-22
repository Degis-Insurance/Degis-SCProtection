// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPayoutPool {
    function newPayout(
        uint256 _poolId,
        uint256 _generation,
        uint256 _amount,
        uint256 _ratio,
        address _poolAddress
    ) external;

    function claim(
        address _user,
        address _crToken,
        uint256 _poolId,
        address _poolAddress
    ) external returns (uint256);
}
