// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IInsurancePool.sol";
import "../../interfaces/IProtectionPool.sol";
import "../../interfaces/IInsurancePoolFactory.sol";
import "../../interfaces/ICoverRightToken.sol";
import "../../interfaces/ICoverRightTokenFactory.sol";

import "../../interfaces/IExchange.sol";

abstract contract PolicyCenterDependencies {
    uint256 constant MAX_COVER_LENGTH = 3;
    uint256 constant MIN_COVER_AMOUNT = 100e6;

    address public executor;
    address public protectionPool;
    address public insurancePoolFactory;
    address public coverRightTokenFactory;
    address public exchange;

    function _setExchange(address _exchange) internal virtual {
        exchange = _exchange;
    }

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setProtectionPool(address _protectionPool) internal virtual {
        protectionPool = _protectionPool;
    }

    function _setInsurancePoolFactory(address _insurancePoolFactory)
        internal
        virtual
    {
        insurancePoolFactory = _insurancePoolFactory;
    }

    function _setCoverRightTokenFactory(address _coverRightTokenFactory)
        internal
        virtual
    {
        coverRightTokenFactory = _coverRightTokenFactory;
    }
}
