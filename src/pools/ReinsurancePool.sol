// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/ReinsurancePoolErrors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ReinsurancePool is
    ReinsurancePoolErrors,
    ERC20("ReinsurancePoolLP", "RLP")
{
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public shield;

    struct PoolInfo {
        address protocolToken;
        uint256 proportion;
    }
    mapping(address => PoolInfo) pools;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _shield) {
        shield = _shield;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function deposit(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();

        IERC20(shield).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();

        IERC20(shield).safeTransfer(msg.sender, _amount);
        _burn(msg.sender, _amount);
    }

    /**
     * @notice Participate in a project's protection
     *         Enjoy the reward from that pool but also take the risk
     */
    function participate() external {}
}
