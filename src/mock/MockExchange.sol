// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockExchange {
    constructor() {}

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(block.timestamp <= deadline);

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        amountOut = amountIn;
        IERC20(path[1]).transfer(to, amountOut);
    }
}
