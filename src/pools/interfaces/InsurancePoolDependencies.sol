// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IInsurancePoolFactory.sol";

abstract contract InsurancePoolDependencies {
    address public executor;
    address public incidentReport;
    address public policyCenter;
    address public insurancePoolFactory;

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }


    function _setIncidentReport(address _incidentReport) internal virtual {
        incidentReport = _incidentReport;
    }

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
    }

    function _setInsurancePoolFactory(address _insurancePoolFactory) internal virtual {
        insurancePoolFactory = _insurancePoolFactory;
    }

  
}
