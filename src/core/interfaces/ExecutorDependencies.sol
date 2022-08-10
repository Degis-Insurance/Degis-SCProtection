// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IInsurancePool.sol";
import "../../interfaces/IProtectionPool.sol";
import "../../interfaces/IInsurancePoolFactory.sol";
import "../../interfaces/IOnboardProposal.sol";
import "../../interfaces/IPolicyCenter.sol";
import "../../interfaces/IIncidentReport.sol";

abstract contract ExecutorDependencies {
    address public policyCenter;
    address public protectionPool;
    address public insurancePoolFactory;
    address public incidentReport;
    address public onboardProposal;

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
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

    function _setIncidentReport(address _incidentReport) internal virtual {
        incidentReport = _incidentReport;
    }

    function _setOnboardProposal(address _onboardProposal) internal virtual {
        onboardProposal = _onboardProposal;
    }
}
