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
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "./InsurancePool.sol";
import "../util/Setters.sol";

import "../interfaces/IExecutor.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Smart Contract Protection
 */
contract InsurancePoolFactory is Ownable, Setters {

    struct PoolInfo {
        string protocolName;
        address poolAddress;
        address protocolToken;
        uint256 maxCapacity;
        uint256 initialpolicyPricePerShield;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    
    // poolIds => pool info
    mapping(uint256 => PoolInfo) public poolInfoById;

    uint256 public poolCounter;
    uint256 public maxCapacity;

    address public administrator;
    address public insurancePool;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    
    event PoolCreated(address poolAddress, uint256 poolId, string protocolName, address protocolToken, uint256 maxCapacity, uint256 initialpolicyPricePerShield);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    

    constructor(address _reinsurancePool, address _shield) {
        poolCounter = 0;
        reinsurancePool = _reinsurancePool;
        shield = _shield;
        setAdministrator(msg.sender);
        poolInfoById[poolCounter] = PoolInfo(
            "ReinsurancePool",
            _reinsurancePool,
            _shield,
            1000000000,
            1
        );
    }
    
    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the pool address for a given pool id
     * @return Array of pool addresses
     */
    function getPoolAddressList() external view returns (address[] memory) {
        address[] memory list = new address[](poolCounter + 1);
        for (uint256 i = 0; i < poolCounter + 1; i++) {
            list[i] = poolInfoById[i].poolAddress;
        }
        return list;
    }

    /**
     * @notice gets the pool counter which indicates the latest pool id
     * @return PoolCounter pool id
     */
    function getPoolCounter() public view returns (uint256) {
        return poolCounter;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //
    
    /**
     * @notice Sets the administrator of the deployed Insurance pools
     * @param _administrator The address of the new administrator
     */
    function setAdministrator(address _administrator) public onlyOwner {
        administrator = _administrator;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    
    /**
     * @notice Creates a new insurance pool
     * @param _name Name of the protocol
     * @param _protocolToken Address of the token used for the protocol
     * @param _maxCapacity Maximum capacity of the pool
     * @param _initialpolicyPricePerShield Initial policy price per shield
     */
    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _initialpolicyPricePerShield
    ) public
     returns (address) {
       bytes32 salt = keccak256(abi.encodePacked(_name));

        bytes memory bytecode = _getInsurancePoolBytecode(
            _protocolToken,
         _maxCapacity,
         _initialpolicyPricePerShield,
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
            _maxCapacity,
            _initialpolicyPricePerShield
        );

        emit PoolCreated(newPoolAddress, poolCounter, _name, _protocolToken, _maxCapacity, _initialpolicyPricePerShield);

        return newPoolAddress;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice gets bytecode for insurance pool creation according to parameters
     *
     * @param _protocolToken address of the protocol token to insure
     * @param _maxCapacity max coverage capacity
     * @param _initialpolicyPricePerShield policy price per shield
     * @param _tokenName name for the new pool
     * @param _symbol symbol for new pool
     */
    function _getInsurancePoolBytecode(
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _initialpolicyPricePerShield,
        string memory _tokenName,
        string memory _symbol
    ) internal virtual view returns (bytes memory) {
        bytes memory bytecode = type(InsurancePool).creationCode;

        // Encodepacked the parameters
        // The minter is set to be the policyCore address
        return
            abi.encodePacked(
                bytecode,
                abi.encode(_protocolToken, _maxCapacity, _tokenName, _symbol, _initialpolicyPricePerShield, administrator)
            );
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
}
