// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface PriorityPoolFactoryEventError {

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
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    error PriorityPoolFactory__OnlyExecutor();
    error PriorityPoolFactory__OnlyPolicyCenter();
    error PriorityPoolFactory__OnlyOwnerOrExecutor();
    error PriorityPoolFactory__OnlyPriorityPool();
    error PriorityPoolFactory__OnlyIncidentReportOrExecutor();
    error PriorityPoolFactory__PoolNotRegistered();
    error PriorityPoolFactory__TokenAlreadyRegistered();
    error PriorityPoolFactory__AlreadyDynamicPool();
    error PriorityPoolFactory__NotOwnerOrFactory();
    error PriorityPoolFactory__WrongLPToken();
}
