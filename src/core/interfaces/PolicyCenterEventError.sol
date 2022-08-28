// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface PolicyCenterEventError {
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event PayoutClaimed(uint256 _amount, address _address);
    event CoverBought(
        address indexed buyer,
        uint256 indexed poolId,
        uint256 coverDuration,
        uint256 coverAmount,
        uint256 premiumInShield
    );
    event MoveLiquidity(uint256 _poolId, uint256 _amount);

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
