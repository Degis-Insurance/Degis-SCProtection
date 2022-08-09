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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/InsurancePoolFactoryDependencies.sol";

import "../util/OwnableWithoutContext.sol";

import "../interfaces/ExternalTokenDependencies.sol";

import "./InsurancePool.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Smart Contract Protection
 */
contract InsurancePoolFactory is
    InsurancePoolFactoryDependencies,
    ExternalTokenDependencies,
    OwnableWithoutContext
{
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
    // poolId => Pool Information
    mapping(uint256 => PoolInfo) public pools;

    uint256 public poolCounter;
    uint256 public sumOfMaxCapacities;

    // Record whether a protocol token or pool address has been registered
    mapping(address => bool) public poolRegistered;
    mapping(address => bool) public tokenRegistered;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event PoolCreated(
        uint256 poolId,
        address poolAddress,
        string protocolName,
        address protocolToken,
        uint256 maxCapacity,
        uint256 policyPricePerShield
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield,
        address _reinsurancePool
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        // stores addresses of the reinsurance pool and degis token
        reinsurancePool = _reinsurancePool;

        // stores information about reinsurance pool, first pool recorded
        pools[poolCounter] = PoolInfo(
            "ReinsurancePool",
            _reinsurancePool,
            _shield,
            100000e18,
            1
        );

        // Register reinsurance pool and degis token
        poolRegistered[_reinsurancePool] = true;
        tokenRegistered[_shield] = true;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the pool address list
     *
     * @return List of pool addresses
     */
    function getPoolAddressList() external view returns (address[] memory) {
        uint256 poolAmount = poolCounter + 1;

        address[] memory list = new address[](poolAmount);

        for (uint256 i; i < poolAmount; ) {
            list[i] = pools[i].poolAddress;

            unchecked {
                ++i;
            }
        }

        return list;
    }

    /**
     * @notice Get the pool information by pool id
     *
     * @param _poolId Pool id
     */
    function getPoolInfo(uint256 _poolId)
        public
        view
        returns (PoolInfo memory)
    {
        return pools[_poolId];
    }

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        _setPolicyCenter(_policyCenter);
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        _setReinsurancePool(_reinsurancePool);
    }

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Creates a new insurance pool
     *
     * @param _name                 Name of the protocol
     * @param _protocolToken        Address of the token used for the protocol
     * @param _maxCapacity          Maximum capacity of the pool
     * @param _priceRatio    Initial policy price per shield
     *
     * @return address Address of the new insurance pool
     */
    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _priceRatio
    ) public returns (address) {
        require(
            msg.sender == owner() || msg.sender == executor,
            "Only owner or executor contract can create a new insurance pool"
        );
        require(!tokenRegistered[_protocolToken], "Already registered");        

        // retrieve reinsurance pool liquidity
        uint256 reinsurancePoolLiquidity = IPolicyCenter(policyCenter).liquidityByPoolId(0);

        // check if reinsurance pool can cover all max capacities
        require(reinsurancePoolLiquidity >= _maxCapacity + sumOfMaxCapacities, "Insufficient liquidity");

        // add new pool max capacity to sum of max capacities
        sumOfMaxCapacities += _maxCapacity;

        bytes32 salt = keccak256(abi.encodePacked(_name));

        bytes memory bytecode = _getInsurancePoolBytecode(
            _protocolToken,
            _maxCapacity,
            _priceRatio,
            _name,
            _name
        );

        // Finish deployment and get the address
        address newPoolAddress = _deploy(bytecode, salt);

        tokenRegistered[_protocolToken] = true;
        poolRegistered[newPoolAddress] = true;

        uint256 currentPoolId = ++poolCounter;

        // Store pool information in Policy Center
        IPolicyCenter(policyCenter).storePoolInformation(
            newPoolAddress,
            _protocolToken,
            currentPoolId
        );
        pools[currentPoolId] = PoolInfo(
            _name,
            newPoolAddress,
            _protocolToken,
            _maxCapacity,
            _priceRatio
        );

        emit PoolCreated(
            currentPoolId,
            newPoolAddress,
            _name,
            _protocolToken,
            _maxCapacity,
            _priceRatio
        );

        return newPoolAddress;
    }

    function updateMaxCapacity(uint256 _maxCapacity) external {
        uint256 difference;
        for (uint256 i = 0; i <= poolCounter; i++) {
            if (pools[i].poolAddress == msg.sender) {
                if (pools[i].maxCapacity > _maxCapacity) {
                    difference = pools[i].maxCapacity - _maxCapacity;
                    sumOfMaxCapacities -= difference;
                } else {
                    difference = _maxCapacity - pools[i].maxCapacity;
                    sumOfMaxCapacities += difference;
                }
            }
        }
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get bytecode for insurance pool creation according to parameters
     *
     * @param _protocolToken Address of the protocol token to insure
     * @param _maxCapacity   Max coverage capacity
     * @param _policyPrice   Policy price
     * @param _tokenName     Name for the new pool
     * @param _symbol        Symbol for new pool
     *
     * @return bytecode Creation bytecode
     */
    function _getInsurancePoolBytecode(
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _policyPrice,
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
                    _policyPrice,
                    owner()
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

    function deregisterAddress(address _tokenAddress) external {
        require(
            msg.sender == owner() || msg.sender == executor,
            "Only owner or executor contract can deregister an address"
        );
        require(tokenRegistered[_tokenAddress], "Address is not registered");
        tokenRegistered[_tokenAddress] = false;
    }
}
