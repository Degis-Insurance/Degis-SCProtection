// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";


import "forge-std/console.sol";

abstract contract FlashLoanPool is IERC3156FlashLender, Initializable {
    address public token;

    // 10000 = 100%
    uint256 public constant FEE = 10;

    event FlashLoanBorrowed(
        address indexed lender,
        address indexed borrower,
        address indexed stablecoin,
        uint256 amount,
        uint256 fee
    );

    error FlashLoanPool__MinnimumNotMet();
    error FlashLoanPool__NotEnoughFunds();
    error FlashLoanPool__NotPaidBack();
    error FlashLoanPool__TokenAddressNotZero();

    function __FlashLoan__Init(address _shield) internal onlyInitializing {
        if (_shield == address(0))
            revert FlashLoanPool__TokenAddressNotZero();
        token = _shield;
    }

    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external override returns (bool) {
        if (_amount == 0) revert FlashLoanPool__MinnimumNotMet();

        uint256 fee = flashFee(_token, _amount);

        uint256 previousBalance = IERC20(_token).balanceOf(
            address(this)
        );

        if (previousBalance < _amount) revert FlashLoanPool__NotEnoughFunds();

        IERC20(_token).transfer(
            address(_receiver),
            _amount
        );

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
        if (finalBalance < previousBalance + fee)
            revert FlashLoanPool__NotPaidBack();

        emit FlashLoanBorrowed(
            address(this),
            address(_receiver),
            _token,
            _amount,
            fee
        );

        return true;
    }

    function flashFee(address _token, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        require(_token == token, "Only shield");
        return (_amount * FEE) / 10000;
    }

    function maxFlashLoan(address _token) external view returns (uint256) {
        require(_token == token, "only shield");
        return IERC20(token).balanceOf(address(this));
    }
}
