// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/CommonDependencies.sol";

interface IPriorityPoolFactory {
    function poolCounter() external view returns (uint256);

    function pools(uint256 _poolId)
        external
        view
        returns (
            string memory name,
            address poolAddress,
            address protocolToken,
            uint256 maxCapacity,
            uint256 basePremiumRatio
        );

    function poolRegistered(address) external view returns (bool);

    function dynamic(address) external view returns (bool);
}

interface IPriorityPool {
    function setCoverIndex(uint256 _newIndex) external;

    function minAssetRequirement() external view returns (uint256);

    function activeCovered() external view returns (uint256);
}

abstract contract ProtectionPoolDependencies is CommonDependencies {
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
