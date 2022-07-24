// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPolicyCenter {
     event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function addPoolId(uint256 _poolId, address _address) external;
    function buyCoverage(uint256 _poolId, uint256 _pay, uint256 _coverAmount, uint256 _length) external;
    function claimPayout(uint256 _poolId, uint256 _amount) external;
    function claimReward(uint256 _poolId) external;
    function deg() view external returns (address);
    function executor() view external returns (address);
    function getInsurancePoolById(uint256 _poolId) view external returns (address);
    function getPoolInfo(uint256 _poolId) view external returns (string memory, address, uint256, uint256, uint256);
    function getPremiumSplits() view external returns (uint256, uint256, uint256);
    function insurancePoolFactory() view external returns (address);
    function insurancePools(uint256) view external returns (address);
    function isPoolAddress(address _poolAddress) view external returns (bool);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function premiumSplits(uint256) view external returns (uint256);
    function proposalCenter() view external returns (address);
    function provideLiquidity(uint256 _poolId, uint256 _amount) external;
    function reinsurancePool() view external returns (address);
    function removeLiquidity(uint256 _poolId, uint256 _amount) external;
    function renounceOwnership() external;
    function rewardTreasuryToReporter(address _reporter) external;
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setPolicyCenter(address _policyCenter) external;
    function setPremiumSplit(uint256 _treasury, uint256 _insurance, uint256 _reinsurance) external;
    function setProposalCenter(address _proposalCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setTokenByPoolId(address _token, uint256 _poolId) external;
    function setVeDeg(address _veDeg) external;
    function shield() view external returns (address);
    function toInsuranceByPoolId(uint256) view external returns (uint256);
    function toSplitByPoolId(uint256) view external returns (uint256);
    function transferOwnership(address newOwner) external;
    function treasury() view external returns (uint256);
    function veDeg() view external returns (address);
}
