// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IProtectionPool {
    event AccRewardsPerShareUpdated(uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Deposit(address indexed user, uint256 amount);
    event EmissionRateUpdated(
        uint256 newEmissionRate,
        uint256 newEmissionEndTime
    );
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event MoveLiquidity(uint256 poolId, uint256 amount);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(address indexed user, uint256 amount);

    function DISTRIBUTION_PERIOD() external view returns (uint256);

    function accumulatedRewardPerShare() external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function deg() external view returns (address);

    function emissionEndTime() external view returns (uint256);

    function emissionRate() external view returns (uint256);

    function endLiquidationPeriod() external;

    function executor() external view returns (address);

    function incidentReport() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function insurancePoolFactory() external view returns (address);

    function insurancePoolLiquidated() external view returns (bool);

    function lastRewardTimestamp() external view returns (uint256);

    function maxCapacity() external view returns (uint256);

    function moveLiquidity(uint256 _poolId, uint256 _amount) external;

    function name() external view returns (string memory);

    function onboardProposal() external view returns (address);

    function owner() external view returns (address);

    function pauseProtectionPool(bool _paused) external;

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

    function providedLiquidity(uint256 _amount, address _provider) external;

    function protectionPool() external view returns (address);

    function removedLiquidity(uint256 _amount, address _provider) external;

    function renounceOwnership() external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setInsurancePoolFactory(address _insurancePoolFactory) external;

    function setOnboardProposal(address _onboardProposal) external;

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

    function transferOwnership(address newOwner) external;

    function updateEmissionRate(uint256 _premium) external;

    function updateRewards() external;

    function veDeg() external view returns (address);

    function totalCovered() external view returns (uint256);

    function updateWhenBuy(uint256 _amount) external;
}
