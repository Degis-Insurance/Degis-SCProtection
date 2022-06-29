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

import "./interfaces/InsurancePool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

pragma solidity ^0.8.13;

contract Executor is Ownable {

    struct Report {
        uint256 poolId;
        uint256 timestamp;
        address reporterAddress;
        uint256 yes;
        uint256 no;
        bool comittee;
        bool team;
        bool pending;
        bool approved;
    }

    struct PoolProposal {
        string protocolName;
        uint256 protocolAddress;
        uint256 reinsuranceSplit;
        uint256 insuranceSplit;
        uint256 timestamp;
        address proposerAddress;
        bool pending;
        bool approved;
    }

    mapping(bytes32 => bool) public queued;
    uint256 public poolBuffer = 7 days;
    uint256 public reportBuffer = 3 days;

    event Queue(
            bytes32 indexed txId,
            address _target,
            uint256 _value,
            string _func,
            bytes _data,
            uint256 _timestamp);


    function getTxId(
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 timestamp
    ) public pure returns (bytes32 txId){
        txId = keccak256(
            abi.encode(
            _target,
            _value,
            _func,
            _data,
            timestamp)
        );
        return txId;
    }
    
    // conflicting
    function queueReport(
        bytes32 _data
    ) external onlyOnwer {
        Report report = getTxId(_poolAddress, _value, _func, _data, _timestamp);
        require(!queued[txId], "tx already queued");
        if (_timestamp < block.timestamp + MIN_DELAY || 
        _timestamp > block.timestamp + MAX_DELAY) {
            require(false, "timestamp out of range");
        }
        queued[txId] = true;
        emit Queue(_target, _value, _func, _data, _timestamp);
    }

    function executeReport(
        address _poolAddress,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp) internal returns (bytes memory) {
            bytes32 txId = getTxId(_poolAddress, _value, _func, _data, _timestamp);
            require(queued[txId], "tx not queued");
            require(block.timestamp > _timestamp, "tx not passed");
            require(block.timestamp < _timestamp + gracePeriod, "tx not ready");


    }
    function executeNewPool(address _protocol,
                            string calldata _protocolName,
                            uint256 _reinsuranceSplit,
                            uint256 _insuranceSplit) internal {}
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