// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPriorityPool {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function coverPrice(uint256 _amount, uint256 _length)
        external
        view
        returns (uint256, uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function deg() external view returns (address);

    function dynamicPremiumRatio() external view returns (uint256);

    function emissionEndTime() external view returns (uint256);

    function emissionRate() external view returns (uint256);

    function endLiquidationDate() external view returns (uint256);

    function executor() external view returns (address);

    function incidentReport() external view returns (address);

    function priorityPoolFactory() external view returns (address);

    function accumulatedRewardPerShare() external view returns (uint256);

    function insuredToken() external view returns (address);

    function lastRewardTimestamp() external view returns (uint256);

    function liquidatePool(uint256 amount) external;

    function liquidated() external view returns (bool);

    function maxCapacity() external view returns (uint256);

    function maxLength() external view returns (uint256);

    function name() external view returns (string memory);

    function onboardProposal() external view returns (address);

    function owner() external view returns (address);

    function paused() external view returns (bool);

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

    function priceRatio() external view returns (uint256);

    function stakedLiquidity(uint256 _amount, address _provider) external;

    function protectionPool() external view returns (address);

    function unstakedLiquidity(uint256 _amount, address _provider) external;

    function renounceOwnership() external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;

    function setMaxCapacity(uint256 _maxCapacity) external;

    function setMaxLength(uint256 _maxLength) external;

    function setOnboardProposal(address _onboardProposal) external;

    function pausePriorityPool(bool _paused) external;

    function setPolicyCenter(address _policyCenter) external;

    function setProtectionPool(address _protectionPool) external;

    function shield() external view returns (address);

    function startTime() external view returns (uint256);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function updateRewards() external;

    function veDeg() external view returns (address);

    function endLiquidation() external;

    function lockedAmount() external view returns (uint256);

    function activeCovered() external view returns (uint256);

    function updateWhenBuy(
        uint256 _amount,
        uint256 _length,
        uint256 _timestampLength
    ) external;
}
