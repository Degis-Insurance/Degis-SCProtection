// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSHIELD is ERC20 {
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

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) public {
        _burn(_to, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function deposit(
        uint256 _type,
        address _token,
        uint256 _transfer,
        uint256 _minReceive
    ) public {
        if (_type == 1) {
            _mint(msg.sender, _minReceive);
            IERC20(_token).transferFrom(msg.sender, address(this), _transfer);
        } else revert("Wrong type");
    }
}
