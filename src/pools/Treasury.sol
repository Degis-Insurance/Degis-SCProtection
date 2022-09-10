// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./SimpleIERC20.sol";

/**
 * @notice Treasury Contract
 *
 *         Treasury will receive 5% of the premium income from policyCenter.
 *         They are counted as different pools.
 *
 *         When a reporter gives a correct report (passed voting and executed),
 *         he will get 10% of the income of that project pool.
 *
 */
contract Treasury {
    uint256 public constant REPORTER_REWARD = 1000;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public owner;

    address public executor;

    address public policyCenter;

    address public shield;

    mapping(uint256 => uint256) public poolIncome;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event ReporterRewarded(address indexed reporter, uint256 amount);

    event NewIncomeToTreasury(uint256 indexed poolId, uint256 amount);

    event ClaimedByOwner(uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _shield,
        address _executor,
        address _policyCenter
    ) {
        executor = _executor;
        shield = _shield;
        policyCenter = _policyCenter;

        owner = msg.sender;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Reward the correct reporter
     *
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
        SimpleIERC20(shield).transfer(_reporter, amount);

        emit ReporterRewarded(_reporter, amount);
    }

    /**
     * @notice Record when receiving new premium income
     *
     *         Only called from policy center
     *
     * @param _poolId Pool id
     * @param _amount Premium amount (shield)
     */
    function premiumIncome(uint256 _poolId, uint256 _amount) external {
        require(msg.sender == policyCenter, "Only policy center");

        poolIncome[_poolId] += _amount;

        emit NewIncomeToTreasury(_poolId, _amount);
    }

    /**
     * @notice Claim shield by the owner
     *
     * @param _amount Amount to claim
     */
    function claim(uint256 _amount) external {
        require(msg.sender == owner, "Only owner");

        SimpleIERC20(shield).transfer(owner, _amount);

        emit ClaimedByOwner(_amount);
    }
}
