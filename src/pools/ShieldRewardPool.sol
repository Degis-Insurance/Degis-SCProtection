// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Shield Reward Pool
 *
 *         Temporarily store the shield reward for Protection Pool
 */
contract ShieldRewardPool {
    address public protectionPool;
    address public shield;

    function distributeShield(uint256 _amount) external {
        require(msg.sender == protectionPool, "Only protection pool");
        require(_amount > 0, "Zero amount to transfer");

        IERC20(shield).transfer(protectionPool, _amount);
    }
}
