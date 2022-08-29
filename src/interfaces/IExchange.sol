// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IExchange {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256);
}
