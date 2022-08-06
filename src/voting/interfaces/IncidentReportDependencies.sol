// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPolicyCenter.sol";
import "../../interfaces/IInsurancePool.sol";
import "../../interfaces/IReinsurancePool.sol";
import "../../interfaces/IInsurancePoolFactory.sol";

abstract contract IncidentReportDependencies {
    address public policyCenter;
    address public reinsurancePool;
    address public insurancePoolFactory;

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
    }

    function _setReinsurancePool(address _reinsurancePool) internal virtual {
        reinsurancePool = _reinsurancePool;
    }

    function _setInsurancePoolFactory(address _insurancePoolFactory)
        internal
        virtual
    {
        insurancePoolFactory = _insurancePoolFactory;
    }
}
