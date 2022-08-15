// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPoolFactory.sol";
import "../../interfaces/IPolicyCenter.sol";
import "../../interfaces/IInsurancePool.sol";
import "../../interfaces/IPremiumRewardPool.sol";

abstract contract ProtectionPoolDependencies {
    uint256 constant UINT256_MAX = type(uint256).max;

    address public priorityPoolFactory;
    address public policyCenter;
    address public incidentReport;
    address public premiumRewardPool;

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

    function _setPremiumRewardPool(address _premiumRewardPool)
        internal
        virtual
    {
        premiumRewardPool = _premiumRewardPool;
    }
}
