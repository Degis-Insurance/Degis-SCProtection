// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPool.sol";
import "../../interfaces/IPriorityPoolFactory.sol";

abstract contract IncidentReportDependencies {
    address public proposalCenter;

    IPriorityPoolFactory public priorityPoolFactory;

    function _setPriorityPoolFactory(address _priorityPoolFactory)
        internal
        virtual
    {
        priorityPoolFactory = IPriorityPoolFactory(_priorityPoolFactory);
    }
}
