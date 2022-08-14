// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

interface ISetAddress {
    function setExecutor(address _executor) external;

    function setPolicyCenter(address _policyCenter) external;

    function setIncidentReport(address _incidentReport) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setProtectionPool(address _protectionPool) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;
}

/**
 * @notice Some helper functions for running test in Solidity
 */
contract BaseTest is Test {
    address public constant ZERO_ADDRESS = address(0);

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );

        vm.label(addr, name);
        return addr;
    }
}
