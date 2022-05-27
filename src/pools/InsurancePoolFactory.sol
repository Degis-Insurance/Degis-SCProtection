// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./InsurancePool.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Smart Contract Protection
 */
contract InsurancePoolFactory is Ownable {
    struct PoolInfo {
        address poolAddress;
        address projectToken;
    }
    // name => pool info
    mapping(string => PoolInfo) pools;

    address[] poolList;

    /**
     * @notice Deploy new insurance pools
     *
     * @param _name  Name of the project
     * @param _token Native token of the project
     */
    function deployPool(string calldata _name, address _token)
        external
        onlyOwner
    {
        bytes memory bytecode = type(InsurancePool).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(_name, _token));

        // Deploy the new pool by create2
        address newPoolAddress = _deploy(bytecode, salt);

        // Store the pool information
        pools[_name].poolAddress = newPoolAddress;
        pools[_name].projectToken = _token;
    }

    function getPoolList() external view returns (address[] memory list) {}

    /**
     * @notice Deploy function with create2
     *
     * @param _code Byte code of the contract (creation code) (including constructor parameters if any)
     * @param _salt Salt for the deployment
     *
     * @return addr The deployed contract address
     */
    function _deploy(bytes memory _code, bytes32 _salt)
        internal
        returns (address addr)
    {
        assembly {
            addr := create2(0, add(_code, 0x20), mload(_code), _salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }
}
