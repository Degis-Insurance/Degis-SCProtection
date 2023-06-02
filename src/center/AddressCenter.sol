// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

contract AddressCenter {
    address public owner;

    bool public initialized;

    // Name => Contract Address
    mapping(string => address) public addressMap;

    modifier onlyOwner() {
        require(msg.sender == owner, "AddressCenter: caller is not the owner");
        _;
    }
 
    modifier alreadyInitialized() {
        require(initialized, "AddressCenter: not already initialized");
        _;
    }

    function setAddress(
        string calldata _name,
        address _address
    ) external onlyOwner {
        addressMap[_name] = _address;
    }

    function setAddresses(
        string[] calldata _names,
        address[] calldata _addresses
    ) external onlyOwner {
        uint256 length = _names.length;
        require(
            length == _addresses.length,
            "AddressCenter: names and addresses length mismatch"
        );
        for (uint256 i; i < length; ) {
            addressMap[_names[i]] = _addresses[i];

            unchecked {
                ++i;
            }
        }
    }

    function finishInitialization() external onlyOwner {
        initialized = true;
    }

    function pause() external onlyOwner {
        initialized = false;
    }

    function getAddress(
        string calldata _name
    ) external view alreadyInitialized returns (address) {
        return addressMap[_name];
    }
}
