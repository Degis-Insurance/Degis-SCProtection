// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPolicyCenter {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Payout(uint256 _amount, address _address);
    event Reward(uint256 _amount, address _address);

    function approvePoolToken(address _token) external;
    function buyCoverage(uint256 _poolId, uint256 _pay, uint256 _coverAmount, uint256 _length) external;
    function calculatePayout(uint256 _poolId, address _insured) view external returns (uint256);
    function calculateReward(uint256 _poolId, address _provider) view external returns (uint256);
    function claimPayout(uint256 _poolId) external;
    function claimReward(uint256 _poolId) external;
    function coverages(uint256, address) view external returns (uint256 amount, uint256 buyDate, uint256 length);
    function deg() view external returns (address);
    function exchange() view external returns (address);
    function executor() view external returns (address);
    function fundsByPoolId(uint256) view external returns (uint256);
    function getCoverage(uint256 _poolId, address _covered) view external returns (uint256, uint256, uint256);
    function getInsurancePoolById(uint256 _poolId) view external returns (address);
    function getPoolInfo(uint256 _poolId) view external returns (string memory, address, uint256, uint256, uint256);
    function getPremiumSplits() view external returns (uint256, uint256);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function insurancePools(uint256) view external returns (address);
    function isPoolAddress(address _poolAddress) view external returns (bool);
    function liquidities(uint256, address) view external returns (uint256 amount, uint256 userDebt, uint256 lastClaim);
    function liquidityByPoolId(uint256) view external returns (uint256);
    function onboardProposal() view external returns (address);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function premiumSplits(uint256) view external returns (uint256);
    function provideLiquidity(uint256 _poolId, uint256 _amount) external;
    function reinsurancePool() view external returns (address);
    function removeLiquidity(uint256 _poolId, uint256 _amount) external;
    function renounceOwnership() external;
    function rewardTreasuryToReporter(address _reporter) external;
    function setDeg(address _deg) external;
    function setExchange(address _exchange) external;
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
    function setPremiumSplit(uint256 _insurance, uint256 _reinsurance) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function shield() view external returns (address);
    function storePoolInformation(address _pool, address _token, uint256 _poolId) external;
    function tokenByPoolId(uint256) view external returns (address);
    function totalRewardsByPoolId(uint256) view external returns (uint256);
    function transferOwnership(address newOwner) external;
    function treasury() view external returns (uint256);
    function veDeg() view external returns (address);
}
