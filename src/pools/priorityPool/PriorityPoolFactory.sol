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

<<<<<<< HEAD:src/pools/priorityPool/PriorityPoolFactory.sol
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./PriorityPoolFactoryDependencies.sol";


import "../../util/OwnableWithoutContext.sol";

import "../../interfaces/ExternalTokenDependencies.sol";

=======
import "./PriorityPoolFactoryDependencies.sol";

import "../../util/OwnableWithoutContext.sol";

import "../../interfaces/ExternalTokenDependencies.sol";

>>>>>>> 36877f9200442a800c555af493a3c721fbed514b:src/pools/PriorityPoolFactory.sol
import "./PriorityPool.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Protocol Protection
 *
 *         Liquidity providers of Protection Pool can stake their LP tokens into priority pools
 *         Benefit:
 *             - Share the 45% part of the premium income (in native token form)
 *         Risk:
 *             - Will be liquidated first to pay for the claim amount
 *
 *
 */
contract PriorityPoolFactory is
    PriorityPoolFactoryDependencies,
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
        uint256 maxCapacity; // max capacity ratio
        uint256 basePremiumRatio;
    }
    // poolId => Pool Information
    mapping(uint256 => PoolInfo) public pools;

    uint256 public poolCounter;
    uint256 public sumOfMaxCapacities;

    mapping(address => bool) public alreadyDynamic;
    uint256 public dynamicPoolCounter;

    // Record whether a protocol token or pool address has been registered
    mapping(address => bool) public poolRegistered;
    mapping(address => bool) public tokenRegistered;

    address public premiumRewardPool;

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

    event DynamicPoolCounterUpdate(address pool, uint256 dynamicPoolCounter);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield,
        address _protectionPool,
        address _payoutPool
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        protectionPool = _protectionPool;

        payoutPool = _payoutPool;

        // Protection pool as pool 0
        pools[0] = PoolInfo("ProtectionPool", _protectionPool, _shield, 0, 0);
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
     * @notice Get total max capacity
     *
     * @return capacity Total capacity
     */
    function totalMaxCapacity() external view returns (uint256 capacity) {
        uint256 poolAmount = poolCounter + 1;

        // Not count the Protection Pool
        for (uint256 i = 1; i < poolAmount; ) {
            capacity += pools[i].maxCapacity;

            unchecked {
                ++i;
            }
        }
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

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        _setPolicyCenter(_policyCenter);
    }

    function setProtectionPool(address _protectionPool) external onlyOwner {
        _setProtectionPool(_protectionPool);
    }

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function addDynamicCounter() external {
        require(poolRegistered[msg.sender], "Only priority pool");

        unchecked {
            ++dynamicPoolCounter;
        }

        alreadyDynamic[msg.sender] = true;

        emit DynamicPoolCounterUpdate(msg.sender, dynamicPoolCounter);
    }

    /**
     * @notice Creates a new insurance pool
     *
     * @param _name          Name of the protocol
     * @param _protocolToken Address of the token used for the protocol
     * @param _maxCapacity   Maximum capacity of the pool
     * @param _basePremiumRatio    Initial policy price per shield
     *
     * @return address Address of the new insurance pool
     */
    function deployPool(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _basePremiumRatio
    ) public returns (address) {
        require(
            msg.sender == owner() || msg.sender == executor,
            "Only owner or executor contract can create a new insurance pool"
        );
        require(!tokenRegistered[_protocolToken], "Already registered");

        // retrieve reinsurance pool liquidity
        uint256 protectionPoolLiquidity = IPolicyCenter(policyCenter)
            .liquidityByPoolId(0);

        // check if reinsurance pool can cover all max capacities
        require(
            protectionPoolLiquidity >= _maxCapacity + sumOfMaxCapacities,
            "Insufficient liquidity"
        );

        // add new pool max capacity to sum of max capacities
        sumOfMaxCapacities += _maxCapacity;

        bytes32 salt = keccak256(abi.encodePacked(_name));

        uint256 currentPoolId = ++poolCounter;

        bytes memory bytecode = _getInsurancePoolBytecode(
            _protocolToken,
            _maxCapacity,
            _basePremiumRatio,
            _name,
            _name,
            currentPoolId
        );

        // Finish deployment and get the address
        address newPoolAddress = _deploy(bytecode, salt);

        tokenRegistered[_protocolToken] = true;
        poolRegistered[newPoolAddress] = true;

        // Store pool information in Policy Center
        IPolicyCenter(policyCenter).storePoolInformation(
            newPoolAddress,
            _protocolToken,
            currentPoolId
        );

        // Register token in premium reward pool
        IPremiumRewardPool(premiumRewardPool).register(
            newPoolAddress,
            _protocolToken
        );

        pools[currentPoolId] = PoolInfo(
            _name,
            newPoolAddress,
            _protocolToken,
            _maxCapacity,
            _basePremiumRatio
        );

        emit PoolCreated(
            currentPoolId,
            newPoolAddress,
            _name,
            _protocolToken,
            _maxCapacity,
            _basePremiumRatio
        );

        return newPoolAddress;
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
     * @param _poolId        Current pool id
     *
     * @return bytecode Creation bytecode
     */
    function _getInsurancePoolBytecode(
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _policyPrice,
        string memory _tokenName,
        string memory _symbol,
        uint256 _poolId
    ) internal view virtual returns (bytes memory) {
        bytes memory bytecode = type(PriorityPool).creationCode;

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
                    owner(),
                    _poolId
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
