// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface PolicyCenterEventError {
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event CoverBought(
        address indexed buyer,
        uint256 indexed poolId,
        uint256 coverDuration,
        uint256 coverAmount,
        uint256 premiumInShield
    );

    event LiquidityProvided(address indexed user, uint256 amount);

    event LiquidityStaked(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event LiquidityStakedWithoutFarming(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event LiquidityUnstaked(
        address indexed user,
        uint256 indexed poolId,
        address priorityLP,
        uint256 amount
    );

    event LiquidityUnstakedWithoutFarming(
        address indexed user,
        uint256 indexed poolId,
        address priorityLP,
        uint256 amount
    );

    event LiquidityRemoved(address indexed user, uint256 amount);

    event PayoutClaimed(address indexed user, uint256 amount);

    event PremiumSplitted(
        uint256 toPriority,
        uint256 toProtection,
        uint256 toTreasury
    );

    event PremiumSwapped(address fromToken, uint256 amount, uint256 received);

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    error PolicyCenter__AlreadyClaimedPayout();
    error PolicyCenter__WrongPriorityPoolID();
    error PolicyCenter__InsufficientCapacity();
    error PolicyCenter__ZeroPremium();
    error PolicyCenter__NoLiquidity();
    error PolicyCenter__NoExchange();
    error PolicyCenter__ZeroAmount();
    error PolicyCenter__NoPayout();
    error PolicyCenter__NonExistentPool();
}
