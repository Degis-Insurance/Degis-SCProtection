// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./PriorityPool.sol";

contract PriorityPoolDeployer is Initializable {
    address public owner;

    address public priorityPoolFactory;
    address public weightedFarmingPool;
    address public protectionPool;
    address public policyCenter;
    address public payoutPool;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize(
        address _priorityPoolFactory,
        address _weightedFarmingPool,
        address _protectionPool,
        address _policyCenter,
        address _payoutPool
    ) public initializer {
        owner = msg.sender;

        priorityPoolFactory = _priorityPoolFactory;
        weightedFarmingPool = _weightedFarmingPool;
        protectionPool = _protectionPool;
        policyCenter = _policyCenter;
        payoutPool = _payoutPool;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
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
        uint256 poolId,
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _basePremiumRatio
    ) public returns (address) {
        require(
            msg.sender == priorityPoolFactory || msg.sender == owner,
            "Only factory"
        );

        address newPoolAddress = _deployPool(
            poolId,
            _name,
            _protocolToken,
            _maxCapacity,
            _basePremiumRatio
        );

        return newPoolAddress;
    }

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
                owner,
                priorityPoolFactory,
                weightedFarmingPool,
                protectionPool,
                policyCenter,
                payoutPool
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
