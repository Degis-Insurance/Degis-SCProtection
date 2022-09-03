// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPolicyCenter {
    event CoverageBought(
        uint256 paid,
        address buyer,
        uint256 poolId,
        uint256 length,
        uint256 amount
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Payout(uint256 _amount, address _address);
    event Reward(uint256 _amount, address _address);

    function approvePoolToken(address _token) external;

    function buyCover(
        uint256 _poolId,
        uint256 _coverAmount,
        uint256 _length,
        uint256 _maxPayment
    ) external returns (address);

    function claimPayout(uint256 _poolId) external;

    function coverages(uint256, address)
        external
        view
        returns (
            uint256 amount,
            uint256 buyDate,
            uint256 length
        );

    function deg() external view returns (address);

    function exchange() external view returns (address);

    function executor() external view returns (address);

    function rewardsByPoolId(uint256) external view returns (uint256);

    function getPoolInfo(uint256 _poolId)
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getPremiumSplits() external view returns (uint256, uint256);

    function incidentReport() external view returns (address);

    function priorityPoolFactory() external view returns (address);

    function insurancePools(uint256) external view returns (address);

    function liquidityByPoolId(uint256) external view returns (uint256);

    function onboardProposal() external view returns (address);

    function owner() external view returns (address);

    function policyCenter() external view returns (address);

    function premiumSplits(uint256) external view returns (uint256);

    function provideLiquidity(uint256 _amount) external;

    function protectionPool() external view returns (address);

    function removeLiquidity(uint256 _amount) external;

    function renounceOwnership() external;

    function rewardTreasuryToReporter(address _reporter) external;

    function setExchange(address _exchange) external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setWeightedFarmingPool(address _weightedFarmingPool) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;

    function setPriceGetter(address _priceGetter) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setPolicyCenter(address _policyCenter) external;

    function setPremiumSplit(uint256 _insurance, uint256 _reinsurance) external;

    function setProtectionPool(address _protectionPool) external;

    function storeCoverTokenInformation(address _coverToken, uint256 _poolId)
        external;

    function shield() external view returns (address);

    function storePoolInformation(
        address _pool,
        address _token,
        uint256 _poolId
    ) external;

    function treasuryTransfer(address _reporter, uint256 _amount) external;

    function tokenByPoolId(uint256) external view returns (address);

    function totalRewardsByPoolId(uint256) external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function treasury() external view returns (uint256);

    function veDeg() external view returns (address);
}
