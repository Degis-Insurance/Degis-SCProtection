// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDegisToken is IERC20 {


    // Mint degis token
    function mintDegis(address _account, uint256 _amount) external;

    // Burn degis token
    function burnDegis(address _account, uint256 _amount) external;
}