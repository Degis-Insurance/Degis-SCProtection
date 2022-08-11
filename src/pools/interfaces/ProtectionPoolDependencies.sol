// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IInsurancePoolFactory.sol";
import "../../interfaces/IPolicyCenter.sol";
import "../../interfaces/IInsurancePool.sol";

abstract contract ProtectionPoolDependencies {
    uint256 constant UINT256_MAX = type(uint256).max;

    address public insurancePoolFactory;
    address public policyCenter;
    address public incidentReport;

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
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
}
