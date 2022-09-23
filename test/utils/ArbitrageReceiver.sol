// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "src/mock/MockArbitrageExchange.sol";


contract ArbitrageReceiver is IERC3156FlashBorrower {

    IERC3156FlashLender lender;
    MockArbitrageExchange arbitrageExchange;
    ERC20 usdc;


    event Balance(uint256 balance);

    constructor (
        IERC3156FlashLender lender_,
        MockArbitrageExchange exchange_,
        ERC20 usdc_
    ) {
        lender = lender_;
        arbitrageExchange = exchange_;
        usdc = usdc_;
    }

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bytes32) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );

        address[] memory t = new address[](3);
        t[0] = address(usdc);
        t[1] = address(token);
        t[2] = address(0x1);
        IERC20(token).approve(address(arbitrageExchange), amount);
        uint256 amountOut = arbitrageExchange.swapExactTokensForTokens(
            amount,
            0,
            t,
            address(this),
            block.timestamp + 1000
        );
        address[] memory t2 = new address[](3);
        t2[0] = address(usdc);
        t2[1] = address(token);
        IERC20(usdc).approve(address(arbitrageExchange), amountOut);
        uint256 amountOut2 = arbitrageExchange.swapExactTokensForTokens(
            amountOut,
            0,
            t2,
            address(this),
            block.timestamp + 1000
        );

        emit Balance(IERC20(token).balanceOf(address(this)));

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount
    ) public {
        IERC20(token).approve(address(lender), 0);

        // Emit balance
        emit Balance(IERC20(token).balanceOf(address(this)));

        lender.flashLoan(this, token, amount, bytes("FlashLoan!"));
    }
}