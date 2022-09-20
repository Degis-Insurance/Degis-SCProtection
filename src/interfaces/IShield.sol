// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../util/SimpleIERC20.sol";

interface IShield is SimpleIERC20 {
    function deposit(
        uint256 _type,
        address _stablecoin,
        uint256 _amount,
        uint256 _minAmount
    ) external;
}
