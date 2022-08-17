// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./IVeDEG.sol";
import "./IDegisToken.sol";

import "./IShield.sol";

/**
 * @notice External token dependencies
 *         Include the tokens that are not deployed by this repo
 *         DEG, veDEG & SHIELD
 *         They are set as immutable
 */

abstract contract ExternalTokenDependencies {
    uint256 public constant SCALE = 1e12;

    IDegisToken public immutable deg;
    IVeDEG public immutable veDeg;
    IShield public immutable shield;

    constructor(
        address _deg,
        address _veDeg,
        address _shield
    ) {
        deg = IDegisToken(_deg);
        veDeg = IVeDEG(_veDeg);
        shield = IShield(_shield);
    }
}
