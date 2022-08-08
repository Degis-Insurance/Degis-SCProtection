// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePool {
     event AccRewardsPerShareUpdated(uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event EmissionRateUpdated(uint256 newEmissionRate, uint256 newEmissionEndTime);
    event Liquidation(uint256 amount, uint256 endDate);
    event LiquidationEnded(uint256 timestamp);
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);

    function CLAIM_PERIOD() view external returns (uint256);
    function DISTRIBUTION_PERIOD() view external returns (uint256);
    function MIN_COVER_AMOUNT() view external returns (uint256);
    function accumulatedRewardPerShare() view external returns (uint256);
    function administrator() view external returns (address);
    function allowance(address owner, address spender) view external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) view external returns (uint256);
    function calculateReward(uint256 _amount, uint256 _userDebt) view external returns (uint256);
    function coveragePrice(uint256 _amount, uint256 _length) view external returns (uint256);
    function decimals() view external returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function deg() view external returns (address);
    function emissionEndTime() view external returns (uint256);
    function emissionRate() view external returns (uint256);
    function endLiquidationDate() view external returns (uint256);
    function executor() view external returns (address);
    function incidentReport() view external returns (address);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function insurancePoolFactory() view external returns (address);
    function insuredToken() view external returns (address);
    function lastRewardTimestamp() view external returns (uint256);
    function liquidatePool() external;
    function liquidated() view external returns (bool);
    function maxCapacity() view external returns (uint256);
    function maxLength() view external returns (uint256);
    function minLength() view external returns (uint256);
    function name() view external returns (string memory);
    function onboardProposal() view external returns (address);
    function owner() view external returns (address);
    function pauseInsurancePool(bool _paused) external;
    function paused() view external returns (bool);
    function policyCenter() view external returns (address);

    function poolInfo() view external returns (bool, uint256, uint256, uint256, uint256, uint256);

    function priceRatio() view external returns (uint256);
    function provideLiquidity(uint256 _amount, address _provider) external;
    function reinsurancePool() view external returns (address);
    function removeLiquidity(uint256 _amount, address _provider) external;
    function renounceOwnership() external;
   
    
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setMaxCapacity(uint256 _maxCapacity) external;
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    
    function shield() view external returns (address);
    function startTime() view external returns (uint256);
    function symbol() view external returns (string memory);
    function totalSupply() view external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function updateEmissionRate(uint256 _premium) external;
    function updateRewards() external;
    function veDeg() view external returns (address);
    function verifyLiquidationEnded() external;
}