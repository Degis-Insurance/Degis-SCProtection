// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./IVeDEG.sol";
import "./IDegisToken.sol";
import "./IShield.sol";
import "./CommonDependencies.sol";

/**
 * @notice External token dependencies
 *         Include the tokens that are not deployed by this repo
 *         DEG, veDEG & SHIELD
 *         They are set as immutable
 */

abstract contract ExternalTokenDependencies is CommonDependencies {
    IDegisToken immutable deg;
    IVeDEG immutable veDeg;
    IShield immutable shield;

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
