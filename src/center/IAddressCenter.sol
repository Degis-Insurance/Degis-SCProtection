// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IAddressCenter {
    function getAddress(string calldata _name) external view returns (address);
}
