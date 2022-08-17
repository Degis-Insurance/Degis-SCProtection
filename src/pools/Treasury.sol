// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/ExternalTokenDependencies.sol";

contract Treasury is ExternalTokenDependencies {
    address public owner;

    address public executor;

    uint256 public constant REPORTER_REWARD = 10;

    event ReporterRewarded(address reporter, uint256 amount);

    constructor(
        address _deg,
        address _veDeg,
        address _shield,
        address _executor
    ) ExternalTokenDependencies(_deg, _veDeg, _shield) {
        executor = _executor;

        owner = msg.sender;
    }

    function rewardReporter(address _reporter) external {
        require(msg.sender == executor, "Only executor");

        uint256 amount = (shield.balanceOf(address(this)) * REPORTER_REWARD) /
            100;

        IERC20(shield).transfer(_reporter, amount);

        emit ReporterRewarded(_reporter, amount);
    }

    function claim(uint256 _amount) external {
        require(msg.sender == owner, "Only owner");

        shield.transfer(owner, _amount);
    }
}
