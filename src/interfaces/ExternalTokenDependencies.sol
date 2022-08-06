// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./IDegisToken.sol";
import "./IVeDEG.sol";

/**
 * @notice External token dependencies
 *         Include the tokens that are not deployed by this repo
 *         DEG, veDEG & SHIELD
 *         They are set as immutable
 */

abstract contract ExternalTokenDependencies {
    uint256 public constant SCALE = 1e12;

    address public immutable deg;
    address public immutable veDeg;
    address public immutable shield;

    constructor(
        address _deg,
        address _veDeg,
        address _shield
    ) {
        deg = _deg;
        veDeg = _veDeg;
        shield = _shield;
    }
}
