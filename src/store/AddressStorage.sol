// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

contract AddressStorage {
    mapping(bytes32 => address) addressBook;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function storeAddress(bytes32 _contractKey, address _contractAddress)
        external
        onlyOwner
    {
        addressBook[_contractKey] = _contractAddress;
    }

    function getAddress(bytes32 _contractKey)
        external
        view
        returns (address contractAddress)
    {
        contractAddress = addressBook[_contractKey];
    }
}
