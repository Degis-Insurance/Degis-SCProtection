// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CoverRightToken is ERC20 {
    
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}
}
