// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";


contract Receiver is IERC3156FlashBorrower {
    IERC3156FlashLender lender;

    event Balance(uint256 balance);

    constructor (
        IERC3156FlashLender lender_
    ) {
        lender = lender_;
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
        // require(
        //     initiator == address(this),
        //     "FlashBorrower: Untrusted loan initiator"
        // );

        // Emit balance
        emit Balance(IERC20(token).balanceOf(address(this)));

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount
    ) public {
        IERC20(token).approve(address(lender), amount);

        // Emit balance
        emit Balance(IERC20(token).balanceOf(address(this)));

        lender.flashLoan(this, token, amount, bytes("FlashLoan!"));
    }
}