// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPoolFactory.sol";
import "../../interfaces/IPolicyCenter.sol";
import "../../interfaces/IProtectionPool.sol";
import "../../interfaces/IPayoutPool.sol";
import "../../interfaces/IWeightedFarmingPool.sol";

abstract contract PriorityPoolDependencies {
    uint256 constant SCALE = 1e12;

    uint256 constant SECONDS_PER_YEAR = 86400 * 365;

    address public policyCenter;
    address public priorityPoolFactory;
    address public protectionPool;
    address public weightedFarmingPool;
    address public payoutPool;
}
