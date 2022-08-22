// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPool.sol";
import "../../interfaces/IPriorityPoolFactory.sol";

import "../../interfaces/IProtectionPool.sol";

abstract contract IncidentReportDependencies {
    address public proposalCenter;
    address public protectionPool;

    IPriorityPoolFactory public priorityPoolFactory;

    function _setPriorityPoolFactory(address _priorityPoolFactory)
        internal
        virtual
    {
        priorityPoolFactory = IPriorityPoolFactory(_priorityPoolFactory);
    }

    function _setProtectionPool(address _protectionPool) internal virtual {
        protectionPool = _protectionPool;
    }
}
