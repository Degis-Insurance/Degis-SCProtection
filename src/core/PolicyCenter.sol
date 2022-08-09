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

import "../libraries/DateTime.sol";

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
    // ReinsurancePool is pool 0
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
    mapping(uint256 => uint256) public liquidityByPoolId;

    // bps distribution of premiums 0: insurance pool, 1: reinsurance pool
    uint256[2] public premiumSplits;

    // uint256 public pendingPremiumToTreasury;
    // uint256 public pendingPremiumToReinsurancePool;

    // amount of degis in treasury
    uint256 public treasury;

    address public priceGetter;

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
        address _reinsurancePool
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        // initializes required reinsurance address and degis token as reinsurance token
        insurancePools[0] = _reinsurancePool;
        tokenByPoolId[0] = _shield;

        _setReinsurancePool(_reinsurancePool);

        // Initialize premium split standard in bps
        // 45% to reinsurancePool, 50% to insurancePool, 5% to treasury
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
     * @return insurancePool premium split in bps
     * @return reinsurancePool premium split in bps
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
     * @notice Reward for liquidity providers
     *
     * @param _poolId Pool id (0 for reinsurance pool)
     *
     * @return uint256 Reward
     */
    function calculateReward(uint256 _poolId, address _provider)
        public
        view
        poolExists(_poolId)
        returns (uint256)
    {
        Liquidity memory liquidity = liquidities[_poolId][_provider];
        if (_poolId > 0) {
            // gets reward from insurance pool
            return
                IInsurancePool(insurancePools[_poolId]).calculateReward(
                    liquidity.amount,
                    liquidity.userDebt
                );
        } else {
            return
                // gets reward from reinsurance pool
                IReinsurancePool(reinsurancePool).calculateReward(
                    liquidity.amount,
                    liquidity.userDebt
                );
        }
    }

    /**
     * @notice returns payout given to cover buyers when report passes
     * @param _poolId pool id to claim from. 0 if reinsurance pool
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
        return amount;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice sets the premium splits used by Policy Center
     * @param _insurance    split for insurance
     * @param _reinsurance  split for reinsurance
     */
    function setPremiumSplit(uint256 _insurance, uint256 _reinsurance)
        external
        onlyOwner
    {
        // up to 1000bps, left over goes to treasury
        require(_insurance + _reinsurance <= 10000, "Invalid split");
        require(_insurance > 0, "has not given an insurance split");
        require(_reinsurance > 0, "has not given a reinsurance split");
        //sets insurance and reinsurance splits
        premiumSplits = [_insurance, _reinsurance];
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

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        _setReinsurancePool(_reinsurancePool);
    }

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
     * @param _poolId               Pool id
     * @param _coverAmount          Amount of tokens to cover
     * @param _coverDuration        1, 2 or 3 months
     */
    function buyCover(
        uint256 _poolId,
        uint256 _coverAmount,
        uint256 _coverDuration
    ) external poolExists(_poolId) {
        require(_coverAmount > 0, "Amount must be greater than 0");
        require(_coverDuration > 0, "Length must be greater than 0");
        require(_poolId > 0, "PoolId must be greater than 0");

        _checkCapacity(_poolId, _coverAmount);

        // Premium in USD(shield)
        uint256 premium = _getCoverPrice(_poolId, _coverAmount, _coverDuration);
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
        emit CoverBought(msg.sender, _poolId, _coverDuration, _coverAmount, premium);

        _splitPremium(_poolId, premium);
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

    // 1000 ReinsurancePool
    // A + B + C <= 1000
    // 200 200 600
    // 100 0   600
    // LP in reinsurancepool
    // remaining liquidity > 700

    function _checkCapacity(uint256 _poolId, uint256 _coverAmount)
        internal
        view
    {
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        require(
            pool.maxCapacity() >= _coverAmount + liquidityByPoolId[_poolId],
            "Exceed max capacity"
        );
    }

    // /**
    //  * @notice Distribute those pending premiums
    //  *         To save gas, we do not transfer premiums for every purchase
    //  */
    // function distributePremium(address _token) external {}

    /**
     * @notice claim rewards from a given pool id
     * @param _poolId pool id to claim rewards from
     */
    function claimReward(uint256 _poolId) public poolExists(_poolId) {
        _claimReward(_poolId, msg.sender);
    }

    /**
     * @notice Provide liquidity to a give pool id
     *
     * @param _poolId Pool id
     * @param _amount Amount of liquidity to provide
     */
    function provideLiquidity(uint256 _poolId, uint256 _amount)
        external
        poolExists(_poolId)
    {
        require(_amount > 0, "Amount must be greater than 0");

        // claim rewards. user debt is updated in _claimReward
        _claimReward(_poolId, msg.sender);

        // adds liquidity to insurance or reinsurance pool
        liquidityByPoolId[_poolId] += _amount;

        Liquidity storage liquidity = liquidities[_poolId][msg.sender];

        if (_poolId > 0) {
            // emits tokens to user from insurnace pool
            IInsurancePool(insurancePools[_poolId]).provideLiquidity(
                _amount,
                msg.sender
            );
        } else {
            // emits tokens to user from reinsurnace pool
            IReinsurancePool(reinsurancePool).provideLiquidity(
                _amount,
                msg.sender
            );
        }
        // upsates user provided amount and last claim
        liquidity.amount += _amount;
        liquidity.lastClaim = block.timestamp;

        IERC20(shield).transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Remove liquidity to a give pool id
     *
     * @param _poolId Pool id
     * @param _amount Amount of liquidity to provide
     */
    function removeLiquidity(uint256 _poolId, uint256 _amount)
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
        uint256 totalSupply;

        if (_poolId > 0) {
            totalSupply = IInsurancePool(insurancePools[_poolId]).totalSupply();
            // burns the full amount of liquidity tokens in users account from insurance pool
            IInsurancePool(insurancePools[_poolId]).removeLiquidity(
                _amount,
                msg.sender
            );
        } else {
            totalSupply = IReinsurancePool(reinsurancePool).totalSupply();

            // burns the full amount of liquidity tokens in users account from reinsurance pool
            IReinsurancePool(reinsurancePool).removeLiquidity(
                _amount,
                msg.sender
            );
        }

        // actual amount is liquidity by LP tokens times amount.
        // If no liquidation and payout, liquidity / totalSupply = 1
        // therefore actual amount = _amount
        uint256 actualAmount = liquidityByPoolId[_poolId] / totalSupply * _amount;


        // removes liquidity from insurance or reinsurance pool
        liquidityByPoolId[_poolId] -= actualAmount;

        // new amount owned by caller
        liquidity.amount -= _amount;
        liquidity.lastClaim = block.timestamp;

        IERC20(shield).transfer(msg.sender, actualAmount);
    }

    /**
     * @notice  Move liquidity to another pool to be used for reinsurance,
                reducing gas costs during liquidation period.
     *
     * @param _amount Amount of liquidity to transfer to insurance pool
     * @param _poolId Id of the pool to move the liquidity to.
     */
    function moveLiquidity(uint256 _poolId, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "Amount must be greater than 0");
        require(IInsurancePool(insurancePools[_poolId]).liquidated(),
         "Insurance pool must have been liquidated");
        liquidityByPoolId[_poolId] -= _amount;
        liquidityByPoolId[0] += _amount;

        emit MoveLiquidity(_poolId, _amount);
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
            // Insurance doesn't need reinsurance
            // Registers removal of funds from insurance pool
            // if its enough to cover all funds
            liquidityByPoolId[_poolId] -= cover.amount;
        } else {
            // Insurance pool needs reinsurance
            // registers removel of funds from insurance and reinsurance pools
            // effectively reinsuring insurance pools
            liquidityByPoolId[_poolId] -= amount;

            // remove from reinsurance pool
            liquidityByPoolId[0] -= (amount - liquidityByPoolId[_poolId]);
        }
        // transfer the totalSupply to user and then ask Reinsurance pool for the remainder
        IERC20(tokenByPoolId[_poolId]).transfer(msg.sender, amount);
        emit Payout(amount, msg.sender);
    }

    /**
     * @notice rewards reporter when a reported insurance pool is liquidated with treasury
     * callable by contract only
     * @param _reporter address of the reporter
     */
    function rewardTreasuryToReporter(address _reporter) external {
        require(msg.sender == executor, "not requested by Executor");

        // 10% of treasury + 2000 DEG
        uint256 reward = (treasury * 1000) / 10000;
        treasury -= reward;

        IDegisToken(deg).transfer(_reporter, reward);
    }

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
                !IReinsurancePool(reinsurancePool).paused(),
                "Reinsurance pool paused"
            );
            IReinsurancePool(reinsurancePool).updateRewards();
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
     * @notice Swap tokens
     *
     * @param _amount    Amount of liquidity to request
     * @param _fromToken Token address to exchange from
     * @param _toToken   Token address to exchange to
     */
    function _swapForExactTokens(
        uint256 _amount,
        address _fromToken,
        address _toToken
    ) internal returns (uint256 receives) {
        address[] memory array = new address[](1);
        array[0] = _fromToken;

        // exchange tokens for deg and return amount of deg received
        receives = IExchange(exchange).swapTokensForExactTokens(
            _amount,
            ((_amount * 99) / 100),
            array,
            _toToken,
            0
        );
    }

    /**
     * @notice Split premium for a pool
     *
     * @param _poolId     Pool id
     * @param _totalSplit Amount of premium to split
     */
    function _splitPremium(uint256 _poolId, uint256 _totalSplit) internal {
        require(_totalSplit > 0, "No funds to split");

        address fromToken = tokenByPoolId[_poolId];

        uint256 toInsurancePool = (_totalSplit * premiumSplits[0]) / 10000;

        // amount to swap for shield and store as reward to reinsurance pool and treasury
        uint256 toSwap = _totalSplit - toInsurancePool;

        // swap native for degis
        uint256 swapped = _swapTokens(toSwap, fromToken, shield);

        uint256 toReinsurancePool = (swapped * premiumSplits[1]) / (10000 - premiumSplits[0]);
        uint256 toTreasury = (swapped * (10000 - premiumSplits[0] - premiumSplits[1]));


        // pendingPremiumToTreasury += toTreasury;
        // pendingPremiumToReinsurancePool += toReinsurancePool;

        // reinsurance pool is pool 0
        rewardsByPoolId[0] += toReinsurancePool;
        treasury += toTreasury;

        IInsurancePool(insurancePools[_poolId]).updateEmissionRate(
            toInsurancePool
        );
        IReinsurancePool(reinsurancePool).updateEmissionRate(
            toReinsurancePool
        );
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
        uint256 endDate = getExpiryDateInternal(block.timestamp, _coverDuration);
        uint256 length = endDate - block.timestamp;
        price = IInsurancePool(insurancePools[_poolId]).coveragePrice(
            _coverAmount,
            length
        );
    }

    /**
     * @dev Gets the expiry date based on cover duration
     * @param today Enter the current timestamp
     * @param coverDuration Enter the number of months to cover. Accepted values: 1-3.
     */
    function getExpiryDateInternal(uint256 today, uint256 coverDuration)
        public
        pure
        returns (uint256)
    {
        // Get the day of the month
        (, , uint256 day) = DateTimeLibrary.timestampToDate(today);

        // Cover duration of 1 month means current month
        // unless today is the 25th calendar day or later
        uint256 monthToAdd = coverDuration - 1;

        if (day >= 25) {
            // Add one month
            monthToAdd += 1;
        }

        return _getNextMonthEndDate(today, monthToAdd);
    }

    function _getNextMonthEndDate(uint256 date, uint256 monthsToAdd)
        private
        pure
        returns (uint256)
    {
        uint256 futureDate = DateTimeLibrary.addMonths(date, monthsToAdd);
        return _getMonthEndDate(futureDate);
    }

    function _getMonthEndDate(uint256 date) private pure returns (uint256) {
        // Get the year and month from the date
        (uint256 year, uint256 month, ) = DateTimeLibrary.timestampToDate(date);

        // Count the total number of days of that month and year
        uint256 daysInMonth = DateTimeLibrary._getDaysInMonth(year, month);

        // Get the month end date
        return
            DateTimeLibrary.timestampFromDateTime(
                year,
                month,
                daysInMonth,
                23,
                59,
                59
            );
    }
}
