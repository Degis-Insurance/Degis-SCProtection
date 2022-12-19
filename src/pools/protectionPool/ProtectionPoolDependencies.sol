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

interface IMiningToken {
    function mint(address _to, uint256 _amount) external;

    function burn(address _to, uint256 _amount) external;
}

abstract contract ProtectionPoolDependencies is CommonDependencies {
    address public priorityPoolFactory;
    address public policyCenter;
    address public incidentReport;
}
