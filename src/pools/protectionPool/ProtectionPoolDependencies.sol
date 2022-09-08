// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/CommonDependencies.sol";

import "../interfaces/SimpleInterface.sol";


abstract contract ProtectionPoolDependencies is CommonDependencies {
    uint256 constant UINT256_MAX = type(uint256).max;

    address public priorityPoolFactory;
    address public policyCenter;
    address public incidentReport;

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
    }

    function _setPriorityPoolFactory(address _priorityPoolFactory)
        internal
        virtual
    {
        priorityPoolFactory = _priorityPoolFactory;
    }

    function _setIncidentReport(address _incidentReport) internal virtual {
        incidentReport = _incidentReport;
    }
}
