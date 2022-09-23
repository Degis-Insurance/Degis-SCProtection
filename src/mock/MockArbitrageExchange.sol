// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IERC20Decimals.sol";
import "forge-std/console.sol";

contract MockArbitrageExchange {
    constructor() {}

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(block.timestamp <= deadline);
        // path[0] is native token with 18 decimals
        // path[1] is MockUSDC with 6 decimals
        uint256 decimalDiff = IERC20Decimals(path[0]).decimals() -
            IERC20Decimals(path[1]).decimals();
        
            // good arbitrage
        if (path[2] == address(0x1)) {
            console.log("good arbitrage");
            IERC20(path[1]).transferFrom(msg.sender, address(this), amountIn); // 1e18 shield
            amountOut = amountIn * 11 / 10; // usdc
            IERC20(path[0]).transfer(to, amountOut);
            // bad arbitrage
        } else if (path[2] == address(0x2)) {
            console.log("bad arbitrage");
            IERC20(path[1]).transferFrom(msg.sender, address(this), amountIn); // 1e18 sheild
            amountOut = amountIn * 9 / 10; // usdc
            IERC20(path[0]).transfer(to, amountOut);
        } else {
            console.log("exchange back to shield");
            IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn); 
            amountOut = amountIn; 
            IERC20(path[1]).transfer(to, amountOut);
        }
        console.log("amountIn", amountIn);
        console.log("amountOut", amountOut);
        
    }
}
