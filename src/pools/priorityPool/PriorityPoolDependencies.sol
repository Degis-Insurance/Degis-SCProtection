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

    address public executor;
    address public incidentReport;
    address public policyCenter;
    address public priorityPoolFactory;
    address public protectionPool;
    address public weightedFarmingPool;

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setIncidentReport(address _incidentReport) internal virtual {
        incidentReport = _incidentReport;
    }

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
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

    function _setProtectionPool(address _protectionPool) internal virtual {
        protectionPool = _protectionPool;
    }
}
