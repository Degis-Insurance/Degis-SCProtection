// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/IShield.sol";
import "../interfaces/IPolicyCenter.sol";

contract Treasury {
    address public owner;

    address public executor;

    address public shield;

    address public policyCenter;

    uint256 public constant REPORTER_REWARD = 1000;

    mapping(uint256 => uint256) public poolIncome;

    event ReporterRewarded(address reporter, uint256 amount);

    constructor(address _shield, address _executor, address _policyCenter) {
        executor = _executor;
        shield = _shield;
        policyCenter = _policyCenter;
        owner = msg.sender;
    }

    /**
     * @notice Reward the correct reporter
     *         Part of the priority pool income will be given to the reporter
     *         Only called from executor when executing a report
     *
     * @param _poolId   Pool id
     * @param _reporter Reporter address
     */
    function rewardReporter(uint256 _poolId, address _reporter) external {
        require(msg.sender == executor, "Only executor");

        uint256 amount = (poolIncome[_poolId] * REPORTER_REWARD) / 10000;

        poolIncome[_poolId] -= amount;
        IPolicyCenter(policyCenter).treasuryTransfer(_reporter, amount);

        emit ReporterRewarded(_reporter, amount);
    }

    /**
     * @notice Record when receiving new premium income
     *
     * @param _poolId Pool id
     * @param _amount Premium amount (shield)
     */
    function premiumIncome(uint256 _poolId, uint256 _amount) external {
        poolIncome[_poolId] += _amount;
    }

    /**
     * @notice Claim shield by the owner
     *
     * @param _amount Amount to claim
     */
    function claim(uint256 _amount) external {
        require(msg.sender == owner, "Only owner");

        SimpleIERC20(shield).transfer(owner, _amount);
    }
}
