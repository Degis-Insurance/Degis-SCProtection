// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePool {
    event AccRewardsPerShareUpdated(uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event EmissionRateUpdated(
        uint256 newEmissionRate,
        uint256 newEmissionEndTime
    );
    event Liquidation(uint256 amount, uint256 endDate);
    event LiquidationEnded(uint256 timestamp);
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Paused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);

    function DISTRIBUTION_PERIOD() external view returns (uint256);

    function PAY_COVER_PERIOD() external view returns (uint256);

    function accumulatedRewardPerShare() external view returns (uint256);

    function administrator() external view returns (address);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function calculateReward(uint256 _amount, uint256 _userDebt)
        external
        view
        returns (uint256);

    function coveragePrice(uint256 _amount, uint256 _length)
        external
        view
        returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function deg() external view returns (address);

    function emissionEndTime() external view returns (uint256);

    function emissionRate() external view returns (uint256);

    function endLiquidationDate() external view returns (uint256);

    function executor() external view returns (address);

    function incidentReport() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function increaseMaxCapacity(uint256 _maxCapacity) external;


    function insurancePoolFactory() external view returns (address);

    function insuredToken() external view returns (address);

    function lastRewardTimestamp() external view returns (uint256);

    function liquidatePool() external;

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

    function provideLiquidity(uint256 _amount, address _provider) external;

    function reinsurancePool() external view returns (address);

    function removeLiquidity(uint256 _amount, address _provider) external;

    function renounceOwnership() external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setInsurancePoolFactory(address _insurancePoolFactory) external;

    function setMaxCapacity(uint256 _maxCapacity) external;

    function setMaxLength(uint256 _maxLength) external;

    function setOnboardProposal(address _onboardProposal) external;

    function pauseInsurancePool(bool _paused) external;

    function setPolicyCenter(address _policyCenter) external;

    function setReinsurancePool(address _reinsurancePool) external;

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

    function endLiquidation() external;

    function lockedAmount() external view returns (uint256);
}
