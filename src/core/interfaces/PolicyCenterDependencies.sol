// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPool.sol";
import "../../interfaces/IProtectionPool.sol";
import "../../interfaces/IPriorityPoolFactory.sol";
import "../../interfaces/ICoverRightToken.sol";
import "../../interfaces/ICoverRightTokenFactory.sol";
import "../../interfaces/IPayoutPool.sol";
import "../../interfaces/IWeightedFarmingPool.sol";
import "../../interfaces/ITreasury.sol";
import "../../interfaces/IExchange.sol";
import "../../interfaces/IERC20Decimals.sol";

abstract contract PolicyCenterDependencies {
    // Max cover length
    // Different priority pools have different max lengths
    // This max length is the maximum of all pools
    // There will also be a check in each pool
    uint256 internal constant MAX_COVER_LENGTH = 3;

    // 10000 = 100%
    uint256 internal constant PREMIUM_TO_PRIORITY = 4500;
    uint256 internal constant PREMIUM_TO_PROTECTION = 5000;
    uint256 internal constant PREMIUM_TO_TREASURY = 500;

    // Swap slippage
    // TODO: Slippage tolerance parameter 10000 as 100%
    uint256 internal constant SLIPPAGE = 1000;

    address public protectionPool;
    address public priceGetter;
    address public priorityPoolFactory;
    address public coverRightTokenFactory;
    address public weightedFarmingPool;
    address public exchange;
    address public payoutPool;
    address public treasury;

    address public dexPriceGetter;
}
