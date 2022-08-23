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

import "./PriorityPoolFactoryDependencies.sol";

import "../../util/OwnableWithoutContext.sol";

import "../../interfaces/ExternalTokenDependencies.sol";

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
    ExternalTokenDependencies,
    OwnableWithoutContext,
    PriorityPoolFactoryDependencies
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

    mapping(address => uint256) public poolAddressToId;

    uint256 public poolCounter;

    // Total max capacity
    uint256 public totalMaxCapacity;

    // Whether a pool is already dynamic
    mapping(address => bool) public dynamic;

    uint256 public dynamicPoolCounter;

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
        uint256 basePremiumRatio
    );

    event DynamicPoolUpdate(
        uint256 poolId,
        address pool,
        uint256 dynamicPoolCounter
    );

    event MaxCapacityUpdated(uint256 totalMaxCapacity);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield,
        address _protectionPool
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        _setProtectionPool(_protectionPool);

        poolRegistered[_protectionPool] = true;
        tokenRegistered[_shield] = true;

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

    function setPremiumRewardPool(address _premiumRewardPool)
        external
        onlyOwner
    {
        _setPremiumRewardPool(_premiumRewardPool);
    }

    function setWeightedFarmingPool(address _weightedFarmingPool)
        external
        onlyOwner
    {
        _setWeightedFarmingPool(_weightedFarmingPool);
    }

    function setProtectionPool(address _protectionPool) external onlyOwner {
        _setProtectionPool(_protectionPool);
    }

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    function setIncidentReport(address _incidentReport) external onlyOwner {
        _setIncidentReport(_incidentReport);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Create a new priority pool
     *         Called by executor when an onboard proposal has passed
     *
     * @param _name             Name of the protocol
     * @param _protocolToken    Address of the token used for the protocol
     * @param _maxCapacity      Maximum capacity of the pool
     * @param _basePremiumRatio Initial policy price per shield
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
            "Only owner or executor"
        );
        require(!tokenRegistered[_protocolToken], "Already registered");

        // Add new pool max capacity to sum of max capacities
        totalMaxCapacity += _maxCapacity;

        uint256 currentPoolId = ++poolCounter;

        address newPoolAddress = _deployPool(
            currentPoolId,
            _name,
            _protocolToken,
            _maxCapacity,
            _basePremiumRatio
        );

        pools[currentPoolId] = PoolInfo(
            _name,
            newPoolAddress,
            _protocolToken,
            _maxCapacity,
            _basePremiumRatio
        );

        tokenRegistered[_protocolToken] = true;
        poolRegistered[newPoolAddress] = true;
        poolAddressToId[newPoolAddress] = currentPoolId;

        // Store pool information in Policy Center
        IPolicyCenter(policyCenter).storePoolInformation(
            newPoolAddress,
            _protocolToken,
            currentPoolId
        );

        // Register reward token in premium reward pool
        IPremiumRewardPool(premiumRewardPool).register(
            newPoolAddress,
            _protocolToken
        );

        // Add reward token in farming pool
        IWeightedFarmingPool(weightedFarmingPool).addPool(_protocolToken);

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

    /**
     * @notice Update a priority pool status to dynamic
     *         Only sent from priority pool
     *         "Dynamic" means:
     *              The priority pool will be counted in the dynamic premium formula
     *
     * @param _poolId Pool id
     */
    function updateDynamicPool(uint256 _poolId) external {
        require(poolRegistered[msg.sender], "Only priority pool");
        require(!dynamic[msg.sender], "Already dynamic");

        dynamic[msg.sender] = true;

        unchecked {
            ++dynamicPoolCounter;
        }

        emit DynamicPoolUpdate(_poolId, msg.sender, dynamicPoolCounter);
    }

    function updateMaxCapaity(bool _isUp, uint256 _diff) external {
        require(poolRegistered[msg.sender], "Only priority pool");

        if (_isUp) {
            totalMaxCapacity += _diff;
        } else totalMaxCapacity -= _diff;

        emit MaxCapacityUpdated(totalMaxCapacity);
    }

    function deregisterAddress(address _poolAddress) external {
        require(
            msg.sender == owner() || msg.sender == executor,
            "Only owner or executor contract can deregister an address"
        );
        require(poolRegistered[_poolAddress], "Address is not registered");

        uint256 poolId = poolAddressToId[_poolAddress];

        address protocolToken = pools[poolId].protocolToken;

        tokenRegistered[protocolToken] = false;
        poolRegistered[_poolAddress] = false;
    }

    function pausePriorityPool(uint256 _poolId, bool _paused) external {
        require(msg.sender == incidentReport, "Only incident report");

        PriorityPool(pools[_poolId].poolAddress).pausePriorityPool(_paused);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    function _deployPool(
        uint256 _poolId,
        string memory _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _baseRatio
    ) internal returns (address addr) {
        bytes memory bytecode = type(PriorityPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_poolId, _name));

        bytes memory bytecodeWithParameters = abi.encodePacked(
            bytecode,
            abi.encode(
                _poolId,
                _name,
                _protocolToken,
                _maxCapacity,
                _baseRatio,
                owner(),
                weightedFarmingPool,
                protectionPool,
                policyCenter
            )
        );

        addr = _deploy(bytecodeWithParameters, salt);
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
