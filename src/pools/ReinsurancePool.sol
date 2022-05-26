// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/ReinsurancePoolErrors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReinsurancePool is
    ReinsurancePoolErrors,
    ERC20("ReinsurancePoolLP", "RLP")
{
    address public shield;

    constructor(address _shield) {
        shield = _shield;
    }

    function deposit(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();

        IERC20(shield).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }
}
