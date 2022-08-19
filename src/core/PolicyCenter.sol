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

import "../libraries/StringUtils.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    using SafeERC20 for IERC20;
    using StringUtils for uint256;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // poolId => address, updated once pools are deployed
    // Protection Pool is pool 0
    mapping(uint256 => address) public priorityPools;
    mapping(uint256 => address) public tokenByPoolId;

    // poolId => user => Cover info
    struct Cover {
        uint256 amount;
        uint256 buyDate;
        uint256 length;
    }
    mapping(uint256 => mapping(address => Cover)) public covers;

    // bps distribution of premiums 0: insurance pool, 1: protection pool
    uint256[2] public premiumSplits;

    address public priceGetter;

    // Year => Month => Total Cover Amount
    mapping(uint256 => mapping(uint256 => uint256)) coverInMonth;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Reward(uint256 _amount, address _address);
    event Payout(uint256 _amount, address _address);
    event CoverBought(
        address indexed buyer,
        uint256 indexed poolId,
        uint256 coverDuration,
        uint256 coverAmount,
        uint256 premiumInShield,
        uint256 premiumInNative
    );
    event MoveLiquidity(uint256 _poolId, uint256 _amount);

    event PremiumSplitted(
        uint256 toPriority,
        uint256 toProtection,
        uint256 toTreasury
    );

    event PremiumSwapped(address fromToken, uint256 amount, uint256 received);

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
        // Peotection pool as pool 0 and with shield token
        priorityPools[0] = _protectionPool;
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
        require(priorityPools[_poolId] != address(0), "Pool not found");
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
        ) = IPriorityPool(priorityPools[_poolId]).poolInfo();
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

    function calculateReward(
        uint256 _poolId,
        uint256 _amount,
        uint256 _debt
    ) public view returns (uint256) {
        IPriorityPool pool = IPriorityPool(priorityPools[_poolId]);
        // Calculate reward amount based on user's liquidity and acc reward per share.
        uint256 reward = (_amount * pool.accumulatedRewardPerShare()) - _debt;

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

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        onlyOwner
    {
        _setPriorityPoolFactory(_priorityPoolFactory);
    }

    /**
     * @notice Store new pool information
     *
     * @param _pool   Address of the priority pool
     * @param _token  Address of the priority pool's native token
     * @param _poolId Pool id
     */
    function storePoolInformation(
        address _pool,
        address _token,
        uint256 _poolId
    ) external {
        require(msg.sender == priorityPoolFactory, "Only factory can store");

        tokenByPoolId[_poolId] = _token;
        priorityPools[_poolId] = _pool;

        _approvePoolToken(_token);
    }

    /**
     * @notice Approve the exchange to swap tokens
     *
     * @param _token Address of the approved token
     */
    function approvePoolToken(address _token) external onlyOwner {
        _approvePoolToken(_token);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Buy new cover for a given pool
     *
     *         Select a pool with parameter "poolId"
     *         Cover amount is in shield and duration is in month
     *         The premium ratio may be dynamic so "maxPayment" is similar to "slippage"
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
    ) external poolExists(_poolId) returns (address) {
        require(_coverAmount >= MIN_COVER_AMOUNT, "Under minimum cover amount");
        require(_withinLength(_coverDuration), "Wrong cover length");
        require(_poolId > 0, "Wrong pool id");

        _checkCapacity(_poolId, _coverAmount);

        // Premium in USD (shield) and duration in second
        (uint256 premium, uint256 timestampDuration) = _getCoverPrice(
            _poolId,
            _coverAmount,
            _coverDuration
        );
        // Check if premium cost is within limits given by user
        require(premium <= _maxPayment, "Premium too high");

        // Mint cover right tokens to buyer
        address crToken = _checkCRToken(_poolId, timestampDuration);
        ICoverRightToken(crToken).mint(_poolId, msg.sender, _coverAmount);

        address nativeToken = tokenByPoolId[_poolId];
        // Premium in project native token (paid in internal function)
        uint256 premiumInNativeToken = _getNativeTokenAmount(
            premium,
            nativeToken
        );

        // Split the premium income and update the pool status
        (
            uint256 premiumToProtectionPool,
            uint256 premiumToPriorityPool,
            uint256 premiumToTreasury
        ) = _splitPremium(nativeToken, premiumInNativeToken);

        IProtectionPool(protectionPool).updateWhenBuy(
            premiumToProtectionPool,
            _coverDuration,
            timestampDuration
        );
        IPriorityPool(priorityPools[_poolId]).updateWhenBuy(
            _coverAmount,
            premiumToPriorityPool,
            _coverDuration,
            timestampDuration
        );
        ITreasury(treasury).premiumIncome(_poolId, premiumToTreasury);
        //TODO: commented because stack too deep
        // emit CoverBought(
        //     msg.sender,
        //     _poolId,
        //     _coverDuration,
        //     _coverAmount,
        //     premium,
        //     premiumInNativeToken
        // );

        return crToken;
    }

    /**
     * @notice Provide liquidity to Protection Pool
     *
     * @param _amount Amount of liquidity(shield) to provide
     */
    function provideLiquidity(uint256 _amount) external {
        require(_amount > 0, "Zero amount");

        // Mint PRO-LP tokens and transfer shield
        IProtectionPool(protectionPool).providedLiquidity(_amount, msg.sender);
        IERC20(shield).transferFrom(msg.sender, protectionPool, _amount);
    }

    /**
     * @notice Stake Protection Pool LP to priority pools
     *
     * @param _poolId Pool id
     * @param _amount Amount of LP tokens to stake
     */
    function stakeLiquidity(uint256 _poolId, uint256 _amount)
        public
        poolExists(_poolId)
    {
        require(_amount > 0, "Zero amount");

        address pool = priorityPools[_poolId];
        address token = tokenByPoolId[_poolId];
        // Update status and mint Prority Pool LP tokens
        IPriorityPool(pool).stakedLiquidity(_amount, msg.sender);
        IWeightedFarmingPool(weightedFarmingPool).stakedLiquidity(_poolId, _amount, token, msg.sender);
        IERC20(protectionPool).transferFrom(msg.sender, pool, _amount);
    }

    /**
     * @notice Unstake Protection Pool LP from priority pools
     *         There may be different generations of priority lp tokens
     *
     * @param _poolId     Pool id
     * @param _priorityLP Priority lp token address to withdraw
     * @param _amount     Amount of LP(priority lp) tokens to withdraw
     */
    function unstakeLiquidity(
        uint256 _poolId,
        address _priorityLP,
        uint256 _amount
    ) external poolExists(_poolId) {
        require(_amount > 0, "Zero amount");

        address token = tokenByPoolId[_poolId];
        // burns the full amount of liquidity tokens in users account from priority pool
        IPriorityPool(priorityPools[_poolId]).unstakedLiquidity(
            _priorityLP,
            _amount,
            msg.sender
        );
        IWeightedFarmingPool(weightedFarmingPool).unstakedLiquidity(_poolId, _amount, token, msg.sender);

    }

    /**
     * @notice Remove liquidity from protection pool
     *
     * @param _amount Amount of liquidity to provide
     */
    function removeLiquidity(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        IProtectionPool(protectionPool).removedLiquidity(_amount, msg.sender);
    }

    /**
     * @notice Claim payout
     *
     * @param _poolId  Pool id
     * @param _crToken Cover right token address
     */
    function claimPayout(uint256 _poolId, address _crToken)
        public
        poolExists(_poolId)
    {
        require(_poolId > 0, "PoolId must be greater than 0");

        // Claim payout from payout pool
        uint256 amount = IPayoutPool(payoutPool).claim(
            msg.sender,
            _crToken,
            _poolId
        );

        emit Payout(amount, msg.sender);
    }



    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Swap tokens to USDC and then to shield
     *
     * @param _fromToken Token address to swap from
     * @param _amount    Amount of token to swap from
     * @param _fromToken Token address to swap from
     */
    function _swapTokens(address _fromToken, uint256 _amount)
        internal
        returns (uint256 received)
    {
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = USDC;

        // Swap for USDC and return the received amount
        received = IExchange(exchange).swapExactTokensForTokens(
            _amount,
            ((_amount * (1000 - SLIPPAGE)) / 1000),
            path,
            address(this),
            block.timestamp + 1
        );

        // Deposit USDC and get back shield
        shield.deposit(1, USDC, received, received);

        emit PremiumSwapped(_fromToken, _amount, received);
    }

    /**
     * @notice Check the cover length
     *
     * @param _length Length to check (in month)
     */
    function _withinLength(uint256 _length) internal pure returns (bool) {
        return _length > 0 && _length <= MAX_COVER_LENGTH;
    }

    /**
     * @notice Check cover right tokens
     *         If the crToken does not exist, it will be deployed here
     *
     * @param _poolId Pool id
     * @param _length Cover length in second
     */
    function _checkCRToken(uint256 _poolId, uint256 _length)
        internal
        returns (address crToken)
    {
        crToken = _getCRTokenAddress(_poolId, _length);
        if (crToken == address(0)) {
            (string memory poolName, , , , ) = IPriorityPoolFactory(
                priorityPoolFactory
            ).pools(_poolId);

            uint256 expiry = block.timestamp + _length;

            (uint256 year, uint256 month, ) = DateTimeLibrary.timestampToDate(
                expiry
            );

            string memory tokenName = string.concat(
                "CR-",
                poolName,
                "-",
                year._toString(),
                "-",
                month._toString()
            );

            crToken = ICoverRightTokenFactory(coverRightTokenFactory)
                .deployCRToken(poolName, _poolId, tokenName, expiry);
        }
    }

    /**
     * @notice Get cover right token address
     *         The address is determined by poolId and expiry(last second of each month)
     *
     * @param _poolId   Pool id
     * @param _length   Length in second
     * @return address  Cover right token address
     */
    function _getCRTokenAddress(uint256 _poolId, uint256 _length)
        internal
        view
        returns (address)
    {
        uint256 expiry = block.timestamp + _length;

        bytes32 salt = keccak256(abi.encodePacked(_poolId, expiry));

        return
            ICoverRightTokenFactory(coverRightTokenFactory).saltToAddress(salt);
    }

    /**
     * @notice Get native token amount to pay
     *
     * @param _premium Premium in USD
     * @param _token   Native token address
     */
    function _getNativeTokenAmount(uint256 _premium, address _token)
        internal
        returns (uint256 premiumInNativeToken)
    {
        // Price in 18 decimals
        uint256 price = IPriceGetter(priceGetter).getLatestPrice(_token);

        premiumInNativeToken = (_premium * 1e12) / price;

        // Pay native tokens
        IERC20(_token).safeTransferFrom(
            msg.sender,
            address(this),
            premiumInNativeToken
        );
    }

    /**
     * @notice Split premium for a pool
     *
     * @param _fromToken  Protocol native token to be swapped
     * @param _totalSplit Amount of premium to split (in native tokens)
     *
     * @return toPriority   Premium to priority pool
     * @return toProtection Premium to protection pool
     * @return toTreasury   Premium to treasury
     */
    function _splitPremium(address _fromToken, uint256 _totalSplit)
        internal
        returns (
            uint256 toPriority,
            uint256 toProtection,
            uint256 toTreasury
        )
    {
        require(_totalSplit > 0, "No funds to split");

        toPriority = (_totalSplit * PREMIUM_TO_PRIORITY) / 10000;

        // Swap native tokens to shield
        uint256 amountToSwap = _totalSplit - toPriority;
        uint256 amountReceived = _swapTokens(_fromToken, amountToSwap);

        toProtection =
            (amountReceived * PREMIUM_TO_PROTECTION) /
            (PREMIUM_TO_PROTECTION + PREMIUM_TO_TREASURY);

        toTreasury = amountReceived - toProtection;

        emit PremiumSplitted(toPriority, toProtection, toTreasury);
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
     * @param _coverAmount   Cover amount (shield)
     * @param _coverDuration Cover length in months (1,2,3)
     */
    function _getCoverPrice(
        uint256 _poolId,
        uint256 _coverAmount,
        uint256 _coverDuration
    ) internal view returns (uint256 price, uint256 timestampDuration) {
        (price, timestampDuration) = IPriorityPool(priorityPools[_poolId])
            .coverPrice(_coverAmount, _coverDuration);
    }

    /**
     * @notice Check priority pool capacity
     *
     * @param _poolId      Pool id
     * @param _coverAmount Amount (shield) to cover
     */
    function _checkCapacity(uint256 _poolId, uint256 _coverAmount)
        internal
        view
    {
        IPriorityPool pool = IPriorityPool(priorityPools[_poolId]);
        uint256 maxCapacityAmount = (IShield(shield).balanceOf(
            address(protectionPool)
        ) * pool.maxCapacity()) / 100;

        require(
            maxCapacityAmount >= _coverAmount + pool.activeCovered(),
            "Insufficient capacity"
        );
    }
}
