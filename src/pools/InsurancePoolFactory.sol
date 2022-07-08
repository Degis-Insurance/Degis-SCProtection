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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "./InsurancePool.sol";

import "../interfaces/IExecutor.sol";

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
        uint256 maxCapacity;
    }
    // poolIds => pool info
    mapping(uint256 => PoolInfo) public poolInfoById;

    uint256 public poolCounter;

    address public DEG;
    address public veDEG;
    address public shield;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;
    address public premiumVault;
    address public insurancePool;

    constructor() {
        poolCounter = 0;
    }

    function getPoolCounter() public view returns (uint256) {
        return poolCounter;
    }

    function setPolicyCenter(address _policyCenter) public onlyOwner {
        policyCenter = _policyCenter;
    }

    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity
    ) external onlyOwner returns (address) {
        bytes memory bytecode = type(InsurancePool).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(_protocolToken, _maxCapacity, _name, _name));

        // Deploy the new pool by create2
        ++poolCounter;
        address newPoolAddress = _deploy(bytecode, salt);
        // Store the pool information
        IPolicyCenter(policyCenter).addPoolId(poolCounter, newPoolAddress);
        poolInfoById[poolCounter] = PoolInfo(
            _name,
            newPoolAddress,
            _protocolToken,
            _maxCapacity
        );

        return newPoolAddress;
    }

    function getPoolAddressList() external view returns (address[] memory) {
        address[] memory list;
        for (uint256 i = 0; i < poolCounter; ++i) {
            list[i] = poolInfoById[i].poolAddress;
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
