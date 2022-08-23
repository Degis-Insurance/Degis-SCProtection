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

import "../../interfaces/IShield.sol";

abstract contract PolicyCenterDependencies {
    uint256 constant MAX_COVER_LENGTH = 3;
    uint256 constant MIN_COVER_AMOUNT = 100e6;

    uint256 constant PREMIUM_TO_PRIORITY = 4500;
    uint256 constant PREMIUM_TO_PROTECTION = 5000;
    uint256 constant PREMIUM_TO_TREASURY = 500;

    // TODO: USDC address
    address constant USDC = address(0x10);

    uint256 constant SLIPPAGE = 10;

    address public executor;
    address public protectionPool;
    address public priceGetter;
    address public priorityPoolFactory;
    address public coverRightTokenFactory;
    address public weightedFarmingPool;
    address public exchange;
    address public payoutPool;

    address public treasury;

    function _setExchange(address _exchange) internal virtual {
        exchange = _exchange;
    }

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setPriceGetter(address _priceGetter) internal virtual {
        priceGetter = _priceGetter;
    }

    function _setProtectionPool(address _protectionPool) internal virtual {
        protectionPool = _protectionPool;
    }

    function _setWeightedFarmingPool(address _weightedFarmingPool)
        internal
        virtual
    {
        weightedFarmingPool = _weightedFarmingPool;
    }

    function _setPriorityPoolFactory(address _priorityPoolFactory)
        internal
        virtual
    {
        priorityPoolFactory = _priorityPoolFactory;
    }

    function _setCoverRightTokenFactory(address _coverRightTokenFactory)
        internal
        virtual
    {
        coverRightTokenFactory = _coverRightTokenFactory;
    }

    function _setPayoutPool(address _payoutPool) internal virtual {
        payoutPool = _payoutPool;
    }
}
