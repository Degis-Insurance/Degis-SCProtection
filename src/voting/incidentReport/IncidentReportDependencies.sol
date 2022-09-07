// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPoolFactory.sol";

interface ISimplePriorityPool {
    function activeCovered() external view returns (uint256);
}

abstract contract IncidentReportDependencies {
    IPriorityPoolFactory public priorityPoolFactory;

    function _setPriorityPoolFactory(address _priorityPoolFactory)
        internal
        virtual
    {
        priorityPoolFactory = IPriorityPoolFactory(_priorityPoolFactory);
    }
}
