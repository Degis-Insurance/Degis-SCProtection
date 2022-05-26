// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./interfaces/ReinsurancePoolErrors.sol";

// import "@openzeppelin/contracts/tokens/ERC20/IERC20.sol";

contract ReinsurancePool is ReinsurancePoolErrors {
    address public shield;

    function deposit(uint256 _amount) external {}
}
