// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPool.sol";
import "../../interfaces/IProtectionPool.sol";
import "../../interfaces/IPriorityPoolFactory.sol";
import "../../interfaces/IOnboardProposal.sol";
import "../../interfaces/IPolicyCenter.sol";
import "../../interfaces/IIncidentReport.sol";
import "../../interfaces/ITreasury.sol";

abstract contract ExecutorDependencies {
    address public protectionPool;
    address public priorityPoolFactory;
    address public incidentReport;
    address public onboardProposal;
    address public policyCenter;

    address public treasury;

    function _setProtectionPool(address _protectionPool) internal virtual {
        protectionPool = _protectionPool;
    }

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

    function _setOnboardProposal(address _onboardProposal) internal virtual {
        onboardProposal = _onboardProposal;
    }

    function _setTreasury(address _treasury) internal virtual {
        treasury = _treasury;
    }
}
