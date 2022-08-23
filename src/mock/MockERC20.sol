// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _decimal
    ) ERC20(_name, _symbol) {
        _decimals = uint8(_decimal);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external {
        _burn(_to, _amount);
    }
}
