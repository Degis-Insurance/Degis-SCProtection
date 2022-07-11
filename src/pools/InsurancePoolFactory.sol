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
    uint256 public maxCapacity;

    address public DEG;
    address public veDEG;
    address public shield;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;
    address public premiumVault;
    address public insurancePool;

    constructor(address _reinsurancePool, address _shield) {
        poolCounter = 0;
        reinsurancePool = _reinsurancePool;
        shield = _shield;
        poolInfoById[poolCounter] = PoolInfo(
            "ReinsurancePool",
            _reinsurancePool,
            _shield,
            1000000000
        );
    }

    function setMaxCapacity(uint256 _maxCapacity) public onlyOwner {
        maxCapacity = _maxCapacity;
    }

    function getPoolCounter() public view returns (uint256) {
        return poolCounter;
    }

    function setDeg(address _deg) external onlyOwner {
        DEG = _deg;
    }

    function setVeDeg(address _veDeg) external onlyOwner {
        veDEG = _veDeg;
    }

    function setShield(address _shield) external onlyOwner {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        policyCenter = _policyCenter;
    }

    function setProposalCenter(address _proposalCenter) external onlyOwner {
        proposalCenter = _proposalCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        reinsurancePool = _reinsurancePool;
    }

    function setExecutor(address _executor) external onlyOwner {
        executor = _executor;
    }

    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity
    ) public
     returns (address) {
       bytes32 salt = keccak256(abi.encodePacked(_name));

        bytes memory bytecode = _getInsurancePoolBytecode(
            _protocolToken,
         _maxCapacity,
        _name,
        _name
        );

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

    function _getInsurancePoolBytecode(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _tokenName,
        string memory _symbol
    ) internal virtual view returns (bytes memory) {
        bytes memory bytecode = type(InsurancePool).creationCode;

        // Encodepacked the parameters
        // The minter is set to be the policyCore address
        return
            abi.encodePacked(
                bytecode,
                abi.encode(_protocolToken, _maxCapacity, _tokenName, _symbol)
            );
    }

    function getPoolAddressList() external view returns (address[] memory) {
        address[] memory list = new address[](poolCounter + 1);
        for (uint256 i = 0; i < poolCounter + 1; i++) {
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
