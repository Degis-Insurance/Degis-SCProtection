// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Exchange {
    string public name;
    constructor () {
        name = "exchange";
    }
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
       external
       returns (uint256 amountOut)
    {
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        amountOut = getAmountOut(amountIn, amountOutMin, amountOutMin);
        IERC20(to).transfer(msg.sender, amountOut);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
       public view returns (uint256)
    {
        
        return amountIn * 99 / 100;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
       external
      
    {
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountInMax);
        amountOut = getAmountOut(amountInMax, amountOut, amountOut);
        IERC20(to).transfer(msg.sender, amountOut);
    }
}