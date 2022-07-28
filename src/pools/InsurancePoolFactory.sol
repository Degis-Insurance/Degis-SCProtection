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

import "../util/ProtocolProtection.sol";
import "./InsurancePool.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Smart Contract Protection
 */
contract InsurancePoolFactory is ProtocolProtection {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    struct PoolInfo {
        string protocolName;
        address poolAddress;
        address protocolToken;
        uint256 maxCapacity;
        uint256 policyPricePerShield;
    }
    mapping(uint256 => PoolInfo) public poolInfoById;

    uint256 public poolCounter;
    uint256 public maxCapacity;

    address public administrator;
    address public insurancePool;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event PoolCreated(
        address poolAddress,
        uint256 poolId,
        string protocolName,
        address protocolToken,
        uint256 maxCapacity,
        uint256 policyPricePerShield
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(address _reinsurancePool, address _degis) {
        // stores addresses of the reinsurance pool and degis token
        reinsurancePool = _reinsurancePool;
        deg = _degis;
        _setAdministrator(msg.sender);
        // stores information about reinsurance pool, first pool recorded
        poolInfoById[poolCounter] = PoolInfo(
            "ReinsurancePool",
            _reinsurancePool,
            _degis,
            100000e18,
            1
        );
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the pool address for a given pool id
     * @return list of pool addresses
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
    function setAdministrator(address _administrator) external onlyOwner {
        _setAdministrator(_administrator);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice                      Creates a new insurance pool
     * @param _name                 Name of the protocol
     * @param _protocolToken        Address of the token used for the protocol
     * @param _maxCapacity          Maximum capacity of the pool
     * @param _policyPricePerToken Initial policy price per shield
     * @return  address             of the new insurance pool
     */
    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _policyPricePerToken
    ) public returns (address) {
        require(
            msg.sender == owner() || msg.sender == executor,
            "Only owner or executor contract can create a new insurance pool"
        );
        bytes32 salt = keccak256(abi.encodePacked(_name));

        bytes memory bytecode = _getInsurancePoolBytecode(
            _protocolToken,
            _maxCapacity,
            _policyPricePerToken,
            _name,
            _name
        );

        ++poolCounter;
        address newPoolAddress = _deploy(bytecode, salt);

        // Store the pool information
        IPolicyCenter(policyCenter).addPoolId(poolCounter, newPoolAddress);
        IPolicyCenter(policyCenter).setTokenByPoolId(
            _protocolToken,
            poolCounter
        );
        poolInfoById[poolCounter] = PoolInfo(
            _name,
            newPoolAddress,
            _protocolToken,
            _maxCapacity,
            _policyPricePerToken
        );

        emit PoolCreated(
            newPoolAddress,
            poolCounter,
            _name,
            _protocolToken,
            _maxCapacity,
            _policyPricePerToken
        );

        return newPoolAddress;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice gets bytecode for insurance pool creation according to parameters
     *
     * @param _protocolToken        address of the protocol token to insure
     * @param _maxCapacity          max coverage capacity
     * @param _policyPricePerToken policy price per shield
     * @param _tokenName            name for the new pool
     * @param _symbol               symbol for new pool
     * @return bytecode             for insurance pool creation
     */
    function _getInsurancePoolBytecode(
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _policyPricePerToken,
        string memory _tokenName,
        string memory _symbol
    ) internal view virtual returns (bytes memory) {
        bytes memory bytecode = type(InsurancePool).creationCode;

        // Encodepacked the parameters
        // The minter is set to be the policyCore address
        return
            abi.encodePacked(
                bytecode,
                abi.encode(
                    _protocolToken,
                    _maxCapacity,
                    _tokenName,
                    _symbol,
                    _policyPricePerToken,
                    administrator
                )
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

    function _setAdministrator(address _administrator) internal onlyOwner {
        administrator = _administrator;
    }
}
