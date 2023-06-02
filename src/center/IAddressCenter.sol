// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IAddressCenter {
    function getAddress(string calldata _name) external view returns (address);
}


abstract contract AddressCenterConstants {
    function getStringHash(string memory _name) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_name));
    }

    bytes32 internal immutable POLICY_CENTER = getStringHash("PolicyCenter");

    bytes32 internal immutable PROTECTION_POOL = getStringHash("ProtectionPool");
    bytes32 internal immutable PRIORITYPOOL_FACTORY = getStringHash("PriorityPoolFactory");

    bytes32 internal immutable EXECUTOR = getStringHash("Executor");
}