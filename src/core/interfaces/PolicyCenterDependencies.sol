// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IInsurancePool.sol";
import "../../interfaces/IReinsurancePool.sol";
import "../../interfaces/IInsurancePoolFactory.sol";
import "../../interfaces/IExchange.sol";

abstract contract PolicyCenterDependencies {
    address public executor;
    address public reinsurancePool;
    address public insurancePoolFactory;
    address public exchange;

    function _setExchange(address _exchange) internal virtual {
        exchange = _exchange;
    }

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setReinsurancePool(address _reinsurancePool) internal virtual {
        reinsurancePool = _reinsurancePool;
    }

    function _setInsurancePoolFactory(address _insurancePoolFactory)
        internal
        virtual
    {
        insurancePoolFactory = _insurancePoolFactory;
    }
}
