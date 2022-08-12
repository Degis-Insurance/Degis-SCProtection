// SPDX-License-Identifier: GPL-3.0-or-later

/*
 //======================================================================\\
 //======================================================================\\
  *******         **********     ***********     *****     ***********
  *      *        *              *                 *       *
  *        *      *              *                 *       *
  *         *     *              *                 *       *
  *         *     *              *                 *       *
  *         *     **********     *       *****     *       ***********
  *         *     *              *         *       *                 *
  *         *     *              *         *       *                 *
  *        *      *              *         *       *                 *
  *      *        *              *         *       *                 *
  *******         **********     ***********     *****     ***********
 \\======================================================================//
 \\======================================================================//
*/

pragma solidity ^0.8.13;

import "../util/OwnableWithoutContext.sol";

import "../mock/MockExchange.sol";

import "./interfaces/PolicyCenterDependencies.sol";

import "../interfaces/ExternalTokenDependencies.sol";
import "../interfaces/IPriceGetter.sol";

import "forge-std/console.sol";

/**
 * @title Policy Center
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the policy center for degis Protocol Protection
 *         Users can buy policies and get payoff here
 *         Sellers can provide liquidity and choose the pools to cover
 *
 */
contract PolicyCenter is
    PolicyCenterDependencies,
    ExternalTokenDependencies,
    OwnableWithoutContext
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // poolId => address, updated once pools are deployed
    // Protection Pool is pool 0
    mapping(uint256 => address) public insurancePools;
    mapping(uint256 => address) public tokenByPoolId;

    // poolId => user => Cover info
    struct Cover {
        uint256 amount;
        uint256 buyDate;
        uint256 length;
    }
    mapping(uint256 => mapping(address => Cover)) public covers;

    //
    mapping(uint256 => uint256) public rewardsByPoolId;

    // poolId => user => Liquidity info
    struct Liquidity {
        uint256 amount;
        uint256 userDebt;
        uint256 lastClaim;
    }
    mapping(uint256 => mapping(address => Liquidity)) public liquidities;

    // amount of liquidity by pool id given by liquidity providers
    // pool 0 represents the total liquidity of the system
    mapping(uint256 => uint256) public liquidityByPoolId;

    // bps distribution of premiums 0: insurance pool, 1: protection pool
    uint256[2] public premiumSplits;

    // uint256 public pendingPremiumToTreasury;
    // uint256 public pendingPremiumToProtectionPool;

    // amount of degis in treasury
    uint256 public treasury;

    address public priceGetter;

    // Year => Month => Total Cover Amount
    mapping(uint256 => mapping(uint256 => uint256)) coverInMonth;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Reward(uint256 _amount, address _address);
    event Payout(uint256 _amount, address _address);
    event CoverBought(
        address buyer,
        uint256 poolId,
        uint256 coverDuration,
        uint256 coverAmount,
        uint256 premium
    );
    event MoveLiquidity(uint256 _poolId, uint256 _amount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield,
        address _protectionPool
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        // initializes required protection address and degis token as protection token
        insurancePools[0] = _protectionPool;
        tokenByPoolId[0] = _shield;

        _setProtectionPool(_protectionPool);

        // Initialize premium split standard in bps
        // 45% to protectionPool, 50% to insurancePool, 5% to treasury
        premiumSplits = [4500, 5000];
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // veirifies if pool exists. used throughout insurance contracts
    modifier poolExists(uint256 _poolId) {
        require(insurancePools[_poolId] != address(0), "Pool not found");
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice returns premium split used by Policy Center
     * @return toPriorityPool   premium split in bps
     * @return toProtectionPool premium split in bps
     */
    function getPremiumSplits() public view returns (uint256, uint256) {
        return (premiumSplits[0], premiumSplits[1]);
    }

    /**
     * @notice returns pool  info for a given pool id
     * @param _poolId                   pool id generated by Policy Center
     * @return paused                   true if pool is paused, false otherwise
     * @return accumulatedRewardPerShare  accumulated reward per each share of the pool
     * @return lastRewardTimestamp      last time reward has been  updated
     * @return emissionEndTime          time emission ends if no new cover is bought
     * @return emissionRate             rate of emission if no new cover is bought
     * @return maxCapacity              max capacity of the pool in shield
     */
    function getPoolInfo(uint256 _poolId)
        public
        view
        poolExists(_poolId)
        returns (
            bool paused,
            uint256 accumulatedRewardPerShare,
            uint256 lastRewardTimestamp,
            uint256 emissionEndTime,
            uint256 emissionRate,
            uint256 maxCapacity
        )
    {
        (
            paused,
            accumulatedRewardPerShare,
            lastRewardTimestamp,
            emissionEndTime,
            emissionRate,
            maxCapacity
        ) = IInsurancePool(insurancePools[_poolId]).poolInfo();
    }

    /**
     * @notice returns information about the cover of a given user
     *
     * @param _poolId Pool id
     * @param _user   User address
     *
     * @return cover Cover info
     */
    function getCover(uint256 _poolId, address _user)
        public
        view
        poolExists(_poolId)
        returns (Cover memory)
    {
        return covers[_poolId][_user];
    }

    /**
     * @notice returns payout given to cover buyers when report passes
     * @param _poolId pool id to claim from. 0 if protection pool
     * @return uint256 amount of payout
     */
    function calculatePayout(uint256 _poolId, address _insured)
        public
        view
        returns (uint256)
    {
        require(_poolId > 0, "Reinsurance pool grants no direct payout");
        // returns amount user has paid for cover
        uint256 amount = covers[_poolId][_insured].amount;

        // TODO: calculate payout according to Cover Index
        return amount;
    }


    function calculateReward(uint256 _poolId, uint256 _amount, uint256 _debt)
        public
        view
        returns (uint256)
    {   
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        // Calculate reward amount based on user's liquidity and acc reward per share.
        uint256 reward = (_amount * pool.accumulatedRewardPerShare()) -
            _debt;

        return reward;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice sets the premium splits used by Policy Center
     * @param _priority    split for priority pool in bps
     * @param _protection  split for protection pool in bps
     */
    function setPremiumSplit(uint256 _priority, uint256 _protection)
        external
        onlyOwner
    {
        // up to 1000bps, left over goes to treasury
        require(_priority + _protection <= 10000, "Invalid split");
        require(_priority > 0, "has not given an insurance split");
        require(_protection > 0, "has not given a protection split");
        //sets insurance and protection splits
        premiumSplits = [_priority, _protection];
    }

    /**
     *  @notice set exchange address to be used for token swaps
     *  @param _exchange address of traderjoe contract
     */
    function setExchange(address _exchange) external onlyOwner {
        exchange = _exchange;
    }

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    function setProtectionPool(address _protectionPool) external onlyOwner {
        _setProtectionPool(_protectionPool);
    }

    //TODO: rename insurance pool factory to priority pool factory?
    function setInsurancePoolFactory(address _insurancePoolFactory)
        external
        onlyOwner
    {
        _setInsurancePoolFactory(_insurancePoolFactory);
    }

    /**
     * @notice Store new pool information
     *
     * @param _pool   Address of the insurance pool
     * @param _token  Address of token that a pool negotiates in
     * @param _poolId Pool id
     */
    function storePoolInformation(
        address _pool,
        address _token,
        uint256 _poolId
    ) external {
        require(msg.sender == insurancePoolFactory, "Only factory can store");

        // maps token address to pool id
        tokenByPoolId[_poolId] = _token;
        // maps pool address to pool id
        insurancePools[_poolId] = _pool;
        // approve token swapping for internal funds management
        _approvePoolToken(_token);
    }

    /**
     * @notice Approve the exchange to swap tokens
     *
     * @param _token Address of the approved token
     */
    function approvePoolToken(address _token) external {
        require(
            msg.sender == owner() || msg.sender == insurancePoolFactory,
            "Only owner or insurancePoolFactory can approve"
        );
        _approvePoolToken(_token);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Buy new cover for a given pool
     *
     * @param _poolId        Pool id
     * @param _coverAmount   Amount to cover
     * @param _coverDuration Cover duration in month (1 ~ 3)
     * @param _maxPayment    Maximum payment user can accept
     */
    function buyCover(
        uint256 _poolId,
        uint256 _coverAmount,
        uint256 _coverDuration,
        uint256 _maxPayment
    ) external poolExists(_poolId) {
        require(_coverAmount >= MIN_COVER_AMOUNT, "Under minimum cover amount");
        require(_withinLength(_coverDuration), "Wrong cover length");
        require(_poolId > 0, "Wrong pool id");

        _checkCapacity(_poolId, _coverAmount);

        // Premium in USD (shield)
        uint256 premium = _getCoverPrice(_poolId, _coverAmount, _coverDuration);

        // Check if premium cost is within limits given by user
        require(premium <= _maxPayment, "Premium too high");

        // Premium in project native token
        uint256 premiumInNativeToken = _getNativeTokenAmount(
            premium,
            tokenByPoolId[_poolId]
        );

        Cover storage cover = covers[_poolId][msg.sender];

        cover.amount += _coverAmount;
        cover.buyDate = block.timestamp + 7 days;
        cover.length = _coverDuration;

        // Pay native tokens
        IERC20(tokenByPoolId[_poolId]).transferFrom(
            msg.sender,
            address(this),
            premiumInNativeToken
        );

        emit CoverBought(
            msg.sender,
            _poolId,
            _coverDuration,
            _coverAmount,
            premium
        );

        // Split the premium income and update the pool status
        (
            uint256 premiumToProtectionPool,
            uint256 premiumToPriorityPool
        ) = _splitPremium(_poolId, _coverAmount);

        IProtectionPool(protectionPool).updateWhenBuy(premiumToProtectionPool, _coverDuration);
        IInsurancePool(insurancePools[_poolId]).updateWhenBuy(premiumToPriorityPool, _coverDuration);
    }

    /**
     * @notice Check insurance pool capacity
     *
     * @param _poolId      Pool id
     * @param _coverAmount Amount to cover
     */
    function _checkCapacity(uint256 _poolId, uint256 _coverAmount)
        internal
        view
    {
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        require(
            pool.maxCapacity() >= _coverAmount + pool.activeCovered(),
            "Insufficient capacity"
        );
    }

    /**
     * @notice claim rewards from a given pool id
     * @param _poolId pool id to claim rewards from
     */
    function claimReward(uint256 _poolId) public poolExists(_poolId) {
        _claimReward(_poolId, msg.sender);
    }

    /**
     * @notice Stake Protection Pool Tokens for increased rewards
     *
     * @param _poolId Pool id
     * @param _amount Amount of LP tokens to stake
     */
    function stakeLiquidityPoolToken(uint256 _poolId, uint256 _amount)
        public
        poolExists(_poolId)
    {
        require(_amount > 0, "Amount must be greater than 0");

        // claim rewards. user debt is updated in _claimReward
        _claimReward(_poolId, msg.sender);

        // adds liquidity to insurance or protection pool
        liquidityByPoolId[_poolId] += _amount;

        Liquidity storage liquidity = liquidities[_poolId][msg.sender];

        // emits tokens to user from insurnace pool
        IInsurancePool(insurancePools[_poolId]).stakedLiquidity(
            _amount,
            msg.sender
        );

        // transfer protection pool tokens from user to contract
        IProtectionPool(protectionPool).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        // upsates user provided amount and last claim
        liquidity.amount += _amount;
        liquidity.lastClaim = block.timestamp;
    }

    /**
     * @notice Provide liquidity to a give protection pool
     *
     * @param _amount Amount of liquidity to provide
     */
    function provideLiquidity(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        // claim rewards. user debt is updated in _claimReward
        // reward is not claimable on protection pool
        // _claimReward(0, msg.sender);

        // adds liquidity to insurance or protection pool
        liquidityByPoolId[0] += _amount;

        Liquidity storage liquidity = liquidities[0][msg.sender];

        // mints tokens to user from protection pool
        IProtectionPool(protectionPool).providedLiquidity(_amount, msg.sender);

        // transfers shield from user to contract
        IERC20(shield).transferFrom(msg.sender, address(this), _amount);
        // upsates user provided amount and last claim
        liquidity.amount += _amount;
        liquidity.lastClaim = block.timestamp;
    }

    /**
     * @notice Remove liquidity to a give pool id
     *
     * @param _poolId Pool id
     * @param _amount Amount of liquidity to provide
     */
    function unstakeLiquidityPoolToken(uint256 _poolId, uint256 _amount)
        external
        poolExists(_poolId)
    {
        require(_amount > 0, "Amount must be greater than 0");

        require(
            _amount <= liquidities[_poolId][msg.sender].amount,
            "Amount must be less than provided liquidity"
        );
        require(
            _amount <= liquidityByPoolId[_poolId],
            "Amount must be less than liquidity"
        );
        require(
            block.timestamp >=
                liquidities[_poolId][msg.sender].lastClaim + 604800,
            "cannot remove liquidity within 7 days of last claim"
        );

        Liquidity storage liquidity = liquidities[_poolId][msg.sender];

        // claim rewards for caller by pool id. user debt is updated in claim reward
        _claimReward(_poolId, msg.sender);

        // totalSupply that wil be used to calculate the amount of shield to be removed
        uint256 totalSupply = IInsurancePool(insurancePools[_poolId])
            .totalSupply();

        // burns the full amount of liquidity tokens in users account from insurance pool
        IInsurancePool(insurancePools[_poolId]).unstakedLiquidity(
            _amount,
            msg.sender
        );

        // actual amount is liquidity by LP tokens times amount.
        // If no liquidation and payout, liquidity / totalSupply = 1
        // therefore actual amount = _amount
        uint256 actualAmount = (liquidityByPoolId[_poolId] / totalSupply) *
            _amount;

        // removes liquidity from insurance or protection pool
        liquidityByPoolId[_poolId] -= actualAmount;

        // new amount owned by caller
        liquidity.amount -= _amount;
        liquidity.lastClaim = block.timestamp;

        IERC20(shield).transfer(msg.sender, actualAmount);
    }

    /**
     * @notice Remove liquidity from protection pool
     *
     * @param _amount Amount of liquidity to provide
     */
    function removeLiquidity(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        require(
            _amount <= liquidities[0][msg.sender].amount,
            "Amount must be less than provided liquidity"
        );
        require(
            _amount <= liquidityByPoolId[0],
            "Amount must be less than liquidity"
        );
        require(
            block.timestamp >= liquidities[0][msg.sender].lastClaim + 604800,
            "cannot remove liquidity within 7 days of last claim"
        );

        Liquidity storage liquidity = liquidities[0][msg.sender];

        // claim rewards for caller by pool id. user debt is updated in claim reward
        // reward is not claimable on protection pool
        // _claimReward(0, msg.sender);

        // totalSupply that wil be used to calculate the amount of shield to be removed
        uint256 totalSupply = IProtectionPool(protectionPool).totalSupply();

        // burns the full amount of liquidity tokens in users account from protection pool
        IProtectionPool(protectionPool).removedLiquidity(_amount, msg.sender);

        // actual amount is liquidity by LP tokens times amount.
        // If no liquidation and payout, liquidity / totalSupply = 1
        // therefore actual amount = _amount
        uint256 actualAmount = (liquidityByPoolId[0] / totalSupply) * _amount;

        // removes liquidity from insurance or protection pool
        liquidityByPoolId[0] -= actualAmount;

        // new amount owned by caller
        liquidity.amount -= _amount;
        liquidity.lastClaim = block.timestamp;

        IERC20(shield).transfer(msg.sender, actualAmount);
    }

    /**
     * @notice claims liquidation payout given a pool id
     *
     * @param _poolId Pool id
     */
    function claimPayout(uint256 _poolId) public poolExists(_poolId) {
        require(_poolId > 0, "PoolId must be greater than 0");

        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);

        Cover storage cover = covers[_poolId][msg.sender];
        //the user can only claim a payout 7 days after the cover was bought

        // exploit protection
        require(cover.buyDate < block.timestamp, "coverage is not yet active");
        require(pool.liquidated(), "pool is not claimable");
        require(
            pool.endLiquidationDate() >= block.timestamp,
            "claim period is over"
        );

        // buy date + length + liquidation date - 5 days buffer
        // intended to fullfil valid coverages accounting for voting period
        require(
            cover.buyDate + (cover.length * 1 days) >=
                pool.endLiquidationDate() - 20 days,
            "coverage has expired"
        );

        require(cover.amount > 0, "no coverage to claim");
        // gets amount to give as payout
        uint256 amount = calculatePayout(_poolId, msg.sender);

        // coverage by user is removed
        cover.amount = 0;
        if (liquidityByPoolId[_poolId] >= amount) {
            // Insurance doesn't need protection
            // Registers removal of funds from insurance pool
            // if its enough to cover all funds
            liquidityByPoolId[_poolId] -= cover.amount;
        } else {
            // Insurance pool needs protection
            // registers removel of funds from insurance and protection pools
            // effectively reinsuring insurance pools
            liquidityByPoolId[_poolId] -= amount;

            // remove from protection pool
            liquidityByPoolId[0] -= (amount - liquidityByPoolId[_poolId]);
        }
        // transfer the totalSupply to user and then ask Reinsurance pool for the remainder
        IERC20(tokenByPoolId[_poolId]).transfer(msg.sender, amount);
        emit Payout(amount, msg.sender);
    }

    /**
     * @notice method to remove treasury funds by contract owner
     *
     * @param _amount       amount to be removed
     */
    function claimTreasury(uint256 _amount) external onlyOwner {
        require(treasury > 0, "No funds to claim");
        require(_amount <= treasury, "Amount exceeds treasury balance");
        treasury -= _amount;
        IERC20(shield).transfer(msg.sender, _amount);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Claim reward for a pool
     *
     * @param _poolId   Pool id to claim rewards from
     * @param _provider Address of the claimer
     */
    function _claimReward(uint256 _poolId, address _provider) internal {
        if (_poolId > 0) {
            require(
                !IInsurancePool(insurancePools[_poolId]).liquidated(),
                "Pool liquidated"
            );
            IInsurancePool(insurancePools[_poolId]).updateRewards();
        } else {
            require(
                !IProtectionPool(protectionPool).paused(),
                "Reinsurance pool paused"
            );
            IProtectionPool(protectionPool).updateRewards();
        }

        // User's liquidity
        Liquidity storage liquidity = liquidities[_poolId][_provider];
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);

        // Calculate reward amount based on user's liquidity and acc reward per share.
        uint256 reward = (liquidity.amount * pool.accumulatedRewardPerShare()) -
            liquidity.userDebt;

        rewardsByPoolId[_poolId] -= reward;

        liquidity.userDebt =
            liquidity.amount *
            pool.accumulatedRewardPerShare();

        IERC20(tokenByPoolId[_poolId]).transfer(_provider, reward);

        emit Reward(reward, _provider);
    }

    /**
     * @notice Swap tokens
     *
     * @param _amount    Amount of liquidity to request
     * @param _fromToken Token address to exchange from
     * @param _toToken   Token address to exchange to
     */
    function _swapTokens(
        uint256 _amount,
        address _fromToken,
        address _toToken
    ) internal returns (uint256 receives) {
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        // exchange tokens for deg and return amount of deg received
        receives = IExchange(exchange).swapExactTokensForTokens(
            _amount,
            ((_amount * 99) / 100),
            path,
            address(this),
            block.timestamp + 1
        );
    }

    /**
     * @notice Check the cover length
     */
    function _withinLength(uint256 _length) internal pure returns (bool) {
        return _length > 0 && _length <= MAX_COVER_LENGTH;
    }

    /**
     * @notice Get native token amount to pay
     *
     * @param _premium Premium in USD
     * @param _token   Native token address
     */
    function _getNativeTokenAmount(uint256 _premium, address _token)
        internal
        returns (uint256)
    {
        // Price in 18 decimals
        uint256 price = IPriceGetter(priceGetter).getLatestPrice(_token);

        return (_premium * 1e12) / price;
    }

    /**
     * @notice Split premium for a pool
     *
     * @param _poolId     Pool id
     * @param _totalSplit Amount of premium to split
     */
    function _splitPremium(uint256 _poolId, uint256 _totalSplit) internal returns (uint256, uint256) {
        require(_totalSplit > 0, "No funds to split");

        address fromToken = tokenByPoolId[_poolId];

        uint256 toInsurancePool = (_totalSplit * premiumSplits[0]) / 10000;

        // amount to swap for shield and store as reward to protection pool and treasury
        uint256 toSwap = _totalSplit - toInsurancePool;

        // swap native for degis
        uint256 swapped = _swapTokens(toSwap, fromToken, shield);

        uint256 toProtectionPool = (swapped / 10000 - premiumSplits[0]) * premiumSplits[1];
        uint256 toTreasury = swapped - toProtectionPool;

        // pendingPremiumToTreasury += toTreasury;
        // pendingPremiumToProtectionPool += toProtectionPool;

        // protection pool is pool 0
        rewardsByPoolId[0] += toProtectionPool;
        treasury += toTreasury;

        return (toInsurancePool, toProtectionPool);
    }

    /**
     * @notice Approve a pool token for the exchange
     *
     * @param _token Token address
     */
    function _approvePoolToken(address _token) internal {
        require(exchange != address(0), "Exchange address not set");
        // approve exchange to swap policy center tokens for deg
        IERC20(_token).approve(exchange, type(uint256).max);
    }

    /**
     * @notice Get cover price from insurance pool
     *
     * @param _poolId        Pool id
     * @param _coverAmount   Cover amount
     * @param _coverDuration Cover length in months (1,2,3)
     */
    function _getCoverPrice(
        uint256 _poolId,
        uint256 _coverAmount,
        uint256 _coverDuration
    ) internal view returns (uint256 price) {
        price = IInsurancePool(insurancePools[_poolId]).coverPrice(
            _coverAmount,
            _coverDuration
        );
    }
}
