// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

abstract contract FlashLoanPool is IERC3156FlashLender {
    address constant SHIELD = address(0x10);
    uint256 constant FEE = 10;

    event FlashLoanBorrowed(
        address indexed lender,
        address indexed borrower,
        address indexed stablecoin,
        uint256 amount,
        uint256 fee
    );

    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external override returns (bool) {
        require(_amount > 0, "Zero amount");
        require(_token == SHIELD, "Only SHIELD");

        uint256 fee = flashFee(_token, _amount);

        uint256 previousBalance = IERC20(_token).balanceOf(address(this));

        IERC20(_token).transfer(address(_receiver), _amount);
        require(
            _receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) ==
                keccak256("ERC3156FlashBorrower.onFlashLoan"),
            "IERC3156: Callback failed"
        );
        IERC20(_token).transferFrom(
            address(_receiver),
            address(this),
            _amount + fee
        );

        uint256 finalBalance = IERC20(_token).balanceOf(address(this));
        require(finalBalance >= previousBalance + fee, "Not enough pay back");

        emit FlashLoanBorrowed(address(this), _receiver, _token, _amount, fee);
        return true;
    }

    function flashFee(address _token, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        return (_amount * FEE) / 10000;
    }
}
