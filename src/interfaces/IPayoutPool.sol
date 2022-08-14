// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPayoutPool {
    function newPayout(uint256 _amount, uint256 _ratio) external;

    function claim(
        address _user,
        address _crToken,
        uint256 _poolId
    ) external returns(uint256);
}
