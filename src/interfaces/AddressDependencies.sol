// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

abstract contract AddressDependencies {
    mapping(address => bool) private initialized;

    modifier initOnce(address _contract) {
        require(!initialized[_contract], "Already initialized");
        _;
        initialized[_contract] = true;
    }
}
