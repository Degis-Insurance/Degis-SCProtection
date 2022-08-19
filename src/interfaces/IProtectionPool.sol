// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IProtectionPool {
    function deg() external view returns (address);

    function executor() external view returns (address);

    function incidentReport() external view returns (address);

    function priorityPoolFactory() external view returns (address);

    function lastRewardTimestamp() external view returns (uint256);

    function maxCapacity() external view returns (uint256);

    function moveLiquidity(uint256 _poolId, uint256 _amount) external;

    function onboardProposal() external view returns (address);

    function pauseProtectionPool(bool _paused) external;

    function policyCenter() external view returns (address);

    function poolInfo()
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    function providedLiquidity(uint256 _amount, address _provider) external;

    function removedLiquidity(uint256 _amount, address _provider)
        external
        returns (uint256);

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setPolicyCenter(address _policyCenter) external;

    function setProtectionPool(address _protectionPool) external;

    function shield() external view returns (address);

    function startTime() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function updateRewards() external;

    function veDeg() external view returns (address);

    function getTotalCovered() external view returns (uint256);

    function updateWhenBuy(
        uint256 _premium,
        uint256 _length,
        uint256 _timestampLength
    ) external;

    function removedLiquidityWhenClaimed(uint256 _amount, address _to) external;
}
