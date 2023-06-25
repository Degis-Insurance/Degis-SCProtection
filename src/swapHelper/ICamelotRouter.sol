// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ICamelotRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        address referrer,
        uint256 deadline
    ) external;
}
