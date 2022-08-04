// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IReinsurancePool {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed user, uint256 amount);
    event MoveLiquidity(uint256 poolId, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(address indexed user, uint256 amount);

    function accumulatedRewardPerShare() view external returns (uint256);
    function addPremium(uint256 _amount) external;
    function allowance(address owner, address spender) view external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) view external returns (uint256);
    function calculateReward(uint256 _amount, uint256 _userDebt) view external returns (uint256);
    function claimReward(address _provider) external;
    function decimals() view external returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function deg() view external returns (address);
    function emissionRate() view external returns (uint256);
    function endLiquidationPeriod() external;
    function executor() view external returns (address);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function insurancePoolFactory() view external returns (address);
    function insurancePoolLiquidated() view external returns (bool);
    function liquidities(address) view external returns (uint256 amount, uint256 userDebt, uint256 lastClaim);
    function moveLiquidity(uint256 _poolId, uint256 _amount) external;
    function name() view external returns (string memory);
    function owner() view external returns (address);
    function paused() view external returns (bool);
    function policyCenter() view external returns (address);
    function poolInfo() external view returns (bool,uint256,uint256,uint256,uint256,uint256);
    function pools(address) view external returns (address protocolAddress, uint256 proportion);
    function proposalCenter() view external returns (address);
    function provideLiquidity(uint256 _amount, address _provider) external;
    function reinsurancePool() view external returns (address);
    function reinsurePool(uint256 _amount, address _address) external;
    function removeLiquidity(uint256 _amount, address _provider) external;
    function renounceOwnership() external;
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function pauseReinsurancePool(bool _paused) external;
    
    function setPolicyCenter(address _policyCenter) external;
    function setProposalCenter(address _proposalCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function shield() view external returns (address);
    function symbol() view external returns (string memory);
    function totalDistributedReward() view external returns (uint256);
    function totalReward() view external returns (uint256);
    function totalSupply() view external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function updateEmissionRate(uint256 _premium) external;
    function updateRewards() external;
    function veDeg() view external returns (address);
}
