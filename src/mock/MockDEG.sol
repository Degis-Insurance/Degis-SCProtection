// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockDEG is ERC20 {
    uint256 public constant MAX_UINT256 = type(uint256).max;

    uint8 public _decimals; //How many decimals to show.

    constructor(
        uint256 _initialAmount,
        string memory _tokenName,
        uint8 _decimalUnits,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        _mint(msg.sender, _initialAmount);

        _decimals = _decimalUnits; // Amount of decimals for display purposes
    }

    function mintDegis(address _account, uint256 _amount) external validMinter {
        _mint(_account, _amount);
    }

    function burnDegis(address _account, uint256 _amount) external validMinter {
        _burn(_account, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
