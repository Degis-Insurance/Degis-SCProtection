// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface PriorityPoolEventError {
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event Liquidation(uint256 amount);
    event EmissionRateUpdated(
        uint256 newEmissionRate,
        uint256 newEmissionEndTime
    );
    event AccRewardsPerShareUpdated(uint256 amount);
    event LiquidationEnded(uint256 timestamp);

    event NewGenerationLPTokenDeployed(
        string poolName,
        uint256 poolId,
        uint256 currentGeneration,
        string name,
        address newLPAddress
    );

    event CoverIndexChanged(uint256 oldIndex, uint256 newIndex);
}
