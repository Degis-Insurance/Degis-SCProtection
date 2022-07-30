// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


interface IExchange {
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) view external returns (uint256);
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) external returns (uint256);
    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] memory path, address to, uint256 deadline) external returns (uint256);
}