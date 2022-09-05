// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

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

        // path[0] is native token with 18 decimals
        // path[1] is MockUSDC with 6 decimals
        uint256 decimalDiff = IERC20Decimals(path[0]).decimals() -
            IERC20Decimals(path[1]).decimals();

        amountOut = amountIn * 10**decimalDiff;

        IERC20(path[1]).transfer(to, amountOut);
    }
}
