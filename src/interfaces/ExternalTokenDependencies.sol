// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./IVeDEG.sol";
import "./IDegisToken.sol";
import "./IShield.sol";
import "./CommonDependencies.sol";

import "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @notice External token dependencies
 *         Include the tokens that are not deployed by this repo
 *         DEG, veDEG & SHIELD
 *         They are set as immutable
 */
abstract contract ExternalTokenDependencies is
    CommonDependencies,
    Initializable
{
    IDegisToken internal deg;
    IVeDEG internal veDeg;
    IShield internal shield;

    function __ExternalToken__Init(
        address _deg,
        address _veDeg,
        address _shield
    ) internal onlyInitializing {
        deg = IDegisToken(_deg);
        veDeg = IVeDEG(_veDeg);
        shield = IShield(_shield);
    }
}
