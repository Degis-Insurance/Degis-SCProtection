// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

/**
 * @notice Some helper functions for running test in Solidity
 */
contract BaseTest is Test {
    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );

        vm.label(addr, name);
        return addr;
    }
}
