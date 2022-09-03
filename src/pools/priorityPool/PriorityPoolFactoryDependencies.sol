// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

abstract contract PriorityPoolFactoryDependencies {
    // Priority Pools need access to executor address
    address public executor;
    address internal policyCenter;
    address internal protectionPool;
    address internal incidentReport;
    address internal premiumRewardPool;
    address internal weightedFarmingPool;
    address internal payoutPool;
    
}
