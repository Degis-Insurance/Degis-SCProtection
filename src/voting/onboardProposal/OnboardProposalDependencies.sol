// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IExecutor.sol";
import "../../interfaces/IPriorityPoolFactory.sol";

abstract contract OnboardProposalDependencies {
    address public executor;
    address public priorityPoolFactory;

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setPriorityPoolFactory(address _priorityPoolFactory)
        internal
        virtual
    {
        priorityPoolFactory = _priorityPoolFactory;
    }
}
