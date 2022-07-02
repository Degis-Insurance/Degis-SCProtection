// SPDX-License-Identifier: GPL-3.0-or-later

/*
 //======================================================================\\
 //======================================================================\\
  *******         **********     ***********     *****     ***********
  *      *        *              *                 *       *
  *        *      *              *                 *       *
  *         *     *              *                 *       *
  *         *     *              *                 *       *
  *         *     **********     *       *****     *       ***********
  *         *     *              *         *       *                 *
  *         *     *              *         *       *                 *
  *        *      *              *         *       *                 *
  *      *        *              *         *       *                 *
  *******         **********     ***********     *****     ***********
 \\======================================================================//
 \\======================================================================//
*/

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./InsurancePool.sol";
import "./PolicyCenter.sol";

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
        string protocolName;
        address poolAddress;
        address protocolToken;
        uint256 vaultSplit;
        uint256 treasurySplit;
        uint256 maxCapacity;
    }
    // poolIds => pool info
    mapping(uint256 => PoolInfo) poolInfoById;

    uint256 public poolCounter;

    constructor(address _poolFactory) {
        owner = msg.sender;
        poolCounter = 0;
    }

    /**
     * @notice Deploy new insurance pools
     *
     * @param _name  Name of the project
     * @param _token Native token of the project
     */
    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _vaultSplit,
        uint256 _treasurySplit
    ) external onlyOwner {
        bytes memory bytecode = type(InsurancePool).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(_name, _protocolToken));

        // Deploy the new pool by create2
        ++poolCounter;
        address newPoolAddress = _deploy(bytecode, salt);
        // Store the pool information
        PolicyCenter(policyCenterAddress).addPoolId(poolCounter, addr);
        poolInfoById[poolCounter] = PoolInfo(
            _name,
            newPoolAddress,
            _protocolToken,
            _vaultSplit,
            _treasurySplit,
            _maxCapacity
        );
    }

    function getPoolList() external view returns (PoolInfo[] memory list) {
        poolInfoById[poolCounter] list;
        for (uint256 i = 0; i < poolCounter; ++i) {
            list[i] = pools[i];
        }
        return list;
    }

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

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //
}
