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

import "../util/ProtocolProtection.sol";
import "../mock/MockExchange.sol";

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
contract PolicyCenter is ProtocolProtection {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // poolIds => address, updated once pools are deployed
    // ReinsurancePool is pool 0
    mapping(uint256 => address) public insurancePools;
    mapping(uint256 => address) public tokenByPoolId;

    // poolId => user => Coverage info
    struct Coverage {
        uint256 amount;
        uint256 buyDate;
        uint256 length;
    }
    mapping(uint256 => mapping(address => Coverage)) public coverages;

    mapping(uint256 => uint256) public fundsByPoolId;
    // amount of rewards by pool Id paid by coverage buyers
    mapping(uint256 => uint256) public totalRewardsByPoolId;

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
    // amount of degis in treasury
    uint256 public treasury;
    // exchange used to trade native tokens for degis
    address public exchange;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Reward(uint256 _amount, address _address);
    event Payout(uint256 _amount, address _address);
    event CoverageBought(
        uint256 paid,
        address buyer,
        uint256 poolId,
        uint256 length,
        uint256 amount
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(address _reinsurancePool, address _degis) {
        // initializes required reinsurance address and degis token as reinsurance token
        insurancePools[0] = _reinsurancePool;
        tokenByPoolId[0] = _degis;
        reinsurancePool = _reinsurancePool;
        deg = _degis;
        // initializes premium split standard in bps
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
     * @return emissionEndTime          time emission ends if no new coverage is bought
     * @return emissionRate             rate of emission if no new coverage is bought
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
     * @notice returns true if given pool address is a valid pool
     * @param _poolAddress pool address
     * @return bool true if pool address is valid
     */
    function isPoolAddress(address _poolAddress) public view returns (bool) {
        // gets the amount of deployed pools by Insurance Pool Factory
        uint256 length = IInsurancePoolFactory(insurancePoolFactory)
            .getPoolCounter();
        // iterates through all pools. If not found, returns false
        for (uint256 i = 0; i < length; i++) {
            if (insurancePools[i] == _poolAddress) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice returns insurance pool address given a pool id
     * @param _poolId pool id generated on Policy Center
     * @return address of insurance pool
     */
    function getInsurancePoolById(uint256 _poolId)
        public
        view
        returns (address)
    {
        return insurancePools[_poolId];
    }

    /**
    @notice returns information about the coverage of a given user
    @param _poolId      address of the covered wallet
    @return _covered    address of covered wallet
    @return buyDate     date bought
    @return length      length of coverage
     */
    function getCoverage(uint256 _poolId, address _covered)
        public
        view
        poolExists(_poolId)
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        Coverage memory coverage = coverages[_poolId][_covered];
        return (coverage.amount, coverage.buyDate, coverage.length);
    }

    /**
     * @notice returns reward to liquidity providers
     * @param _poolId pool id to claim from. 0 if reinsurance pool
     * @return uint256 amount of reward
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
     * @notice returns payout given to coverage buyers when report passes
     * @param _poolId pool id to claim from. 0 if reinsurance pool
     * @return uint256 amount of payout
     */
    function calculatePayout(uint256 _poolId, address _insured)
        public
        view
        returns (uint256)
    {
        require(_poolId > 0, "Reinsurance pool grants no direct payout");
        // returns amount user has paid for coverage
        uint256 amount = coverages[_poolId][_insured].amount;
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

    /**
     * @notice sets the insurance pool factory address
     * @param _pool  address of the insurance pool
     * @param _token address of token that a pool negotiates in
     * @param _poolId id of the pool
     */
    function storePoolInformation(
        address _pool,
        address _token,
        uint256 _poolId
    ) external {
        require(
            msg.sender == owner() || msg.sender == insurancePoolFactory,
            "Only owner or insurancePoolFactory can set tokens"
        );
        // maps token address to pool id
        tokenByPoolId[_poolId] = _token;
        // maps pool address to pool id
        insurancePools[_poolId] = _pool;
        // approve token swapping for internal fudns management
        _approvePoolToken(_token);
    }

    /**
     * @notice approves exchange to swap tokens in control of policy center
     * @param _token        address of the approved token
     */
    function approvePoolToken(address _token) external {
        require(
            msg.sender == owner() || msg.sender == insurancePoolFactory,
            "Only owner or insurancePoolFactory can set tokens"
        );
        _approvePoolToken(_token);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Buy new coverage for a given pool
     * @param _poolId       pool id generated on Policy Center
     * @param _pay          amount paid to cover amount of tokens
     * @param _coverAmount  amount of tokens to cover
     * @param _length       lenght of coverage in days
     */
    function buyCoverage(
        uint256 _poolId,
        uint256 _pay,
        uint256 _coverAmount,
        uint256 _length
    ) external poolExists(_poolId) {
        require(_coverAmount > 0, "Amount must be greater than 0");
        require(_length > 0, "Length must be greater than 0");
        require(_poolId > 0, "PoolId must be greater than 0");
        require(_pay > 0, "Pay must be greater than 0");
        require(
            IInsurancePool(insurancePools[_poolId]).maxCapacity() >=
                _pay + fundsByPoolId[_poolId],
            "exceeds max capacity"
        );
        uint256 price = IInsurancePool(insurancePools[_poolId]).coveragePrice(
            _coverAmount,
            _length
        );
        // checks if user is paying just enough to cover the amount of tokens
        require(price == _pay, "pay does not correspond to price");
        //register coverage

        totalRewardsByPoolId[_poolId] += _pay;
        Coverage storage coverage = coverages[_poolId][msg.sender];
        coverage.amount += _coverAmount;
        // initial 7 days buffer so pool cannot be exploited
        coverage.buyDate = block.timestamp + 7 days;
        coverage.length = _length;

        uint256 toTransfer = _pay;

        // updates pool distribution based on paid amount
        IERC20(tokenByPoolId[_poolId]).transferFrom(
            msg.sender,
            address(this),
            toTransfer
        );
        emit CoverageBought(
            toTransfer,
            msg.sender,
            _pay,
            _length,
            _coverAmount
        );
        _splitPremium(_poolId, toTransfer);
    }

    /**
     * @notice claim rewards from a given pool id
     * @param _poolId pool id to claim rewards from
     */
    function claimReward(uint256 _poolId) public poolExists(_poolId) {
        _claimReward(_poolId, msg.sender);
    }

    /**
     * @notice provide liquidity to a give pool id
     * @param _poolId pool id generated on Policy Center
     * @param _amount amount of liquidity to provide
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
     * @notice remove liquidity to a give pool id
     * @param _poolId pool id generated on Policy Center
     * @param _amount amount of liquidity to provide
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
        console.log("Start");
        // claim rewards for caller by pool id. user debt is updated in claim reward
        _claimReward(_poolId, msg.sender);
        console.log("End");
        console.log("liquidity by pool id", liquidityByPoolId[_poolId]);
        // removes liquidity from insurance or reinsurance pool
        liquidityByPoolId[_poolId] -= _amount;

        if (_poolId > 0) {
            // burns liquidity tokens in users account from insurance pool
            IInsurancePool(insurancePools[_poolId]).removeLiquidity(
                _amount,
                msg.sender
            );
        } else {
            // burns liquidity tokens in users account from reinsurance pool
            IReinsurancePool(reinsurancePool).removeLiquidity(
                _amount,
                msg.sender
            );
        }

        // new amount owned by caller
        liquidity.amount -= _amount;
        liquidity.lastClaim = block.timestamp;

        IERC20(shield).transfer(msg.sender, _amount);
    }

    /**
     * @notice claims liquidation payout given a pool id
     *
     * @param _poolId Pool id
     */
    function claimPayout(uint256 _poolId) public poolExists(_poolId) {
        require(_poolId > 0, "PoolId must be greater than 0");

        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);

        Coverage storage coverage = coverages[_poolId][msg.sender];
        //the user can only claim a payout 7 days after the coverage was bought

        // exploit protection
        require(
            coverage.buyDate < block.timestamp,
            "coverage is not yet active"
        );
        require(pool.liquidated(), "pool is not claimable");
        require(
            pool.endLiquidationDate() >= block.timestamp,
            "claim period is over"
        );

        // buy date + length + liquidation date - 5 days buffer
        // intended to fullfil valid coverages accounting for voting period
        require(
            coverage.buyDate + (coverage.length * 1 days) >=
                pool.endLiquidationDate() - 20 days,
            "coverage has expired"
        );

        require(coverage.amount > 0, "no coverage to claim");
        // gets amount to give as payout
        uint256 amount = calculatePayout(_poolId, msg.sender);

        // coverage by user is removed
        coverage.amount = 0;
        if (liquidityByPoolId[_poolId] >= amount) {
            // Insurance doesn't need reinsurance
            // Registers removal of funds from insurance pool
            // if its enough to cover all funds
            fundsByPoolId[_poolId] -= coverage.amount;
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

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice claims rewards from a given pool id
     * @param _poolId   pool id to claim rewards from
     * @param _provider address of the claimer
     */
    function _claimReward(uint256 _poolId, address _provider) internal {
        if (_poolId > 0) {
            require(
                !IInsurancePool(insurancePools[_poolId]).liquidated(),
                "Pool has been liquidated, cannot claim stake"
            );
            IInsurancePool(insurancePools[_poolId]).updateRewards();
        } else {
            require(
                !IReinsurancePool(reinsurancePool).paused(),
                "a pool has been liquidated, unable to remove liquidity"
            );
            IReinsurancePool(reinsurancePool).updateRewards();
        }
        // retrieve a user's liquidity from a pool
        Liquidity storage liquidity = liquidities[_poolId][_provider];
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);

        console.log("pool acc:", pool.accumulatedRewardPerShare());
        console.log("amount", liquidity.amount);
        console.log("Debt", liquidity.userDebt);
        // Calculate reward amount based on user's liquidity and acc reward per share.
        uint256 reward = (liquidity.amount * pool.accumulatedRewardPerShare()) -
            liquidity.userDebt;

        console.log("funds", fundsByPoolId[_poolId]);
        fundsByPoolId[_poolId] -= reward;

        liquidity.userDebt =
            liquidity.amount *
            pool.accumulatedRewardPerShare();

        IERC20(tokenByPoolId[_poolId]).transfer(_provider, reward);

        emit Reward(reward, _provider);
    }

    /**
     * @notice swaps tokens for deg
     *
     * @param _amount       amount of liquidity to request
     * @param _fromToken    token address to exchange from
     * @param _toToken      token address to exchange to
     */
    function _swapTokens(
        uint256 _amount,
        address _fromToken,
        address _toToken
    ) internal returns (uint256 receives) {
        address[] memory array = new address[](1);
        array[0] = _fromToken;
        // exchange tokens for deg and return amount of deg received
        receives = IExchange(exchange).swapExactTokensForTokens(
            _amount,
            ((_amount * 99) / 100),
            array,
            _toToken,
            0
        );
    }

    /**
     * @notice swaps tokens for deg
     *
     * @param _amount       Amount of liquidity to request
     * @param _fromToken    Token address to exchange from
     * @param _toToken      Token address to exchange to
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
     * @notice splits received premium given a pool id
     * @param _poolId pool id generated on Policy Center
     */
    function _splitPremium(uint256 _poolId, uint256 _amount)
        internal
        poolExists(_poolId)
    {
        require(_amount > 0, "No funds to split");
        address fromToken = tokenByPoolId[_poolId];
        uint256 totalSplit = _amount;

        uint256 toInsurancePool = (totalSplit * premiumSplits[0]) / 10000;
        uint256 toReinsurancePool = (totalSplit * premiumSplits[1]) / 10000;

        // treasury receives left overs
        uint256 toTreasury = totalSplit - toInsurancePool - toReinsurancePool;

        // swap native for degis
        uint256 treasuryReceives = _swapTokens(toTreasury, fromToken, deg);
        uint256 reinsuranceReceives = _swapTokens(
            toReinsurancePool,
            fromToken,
            deg
        );
        treasury += treasuryReceives;
        fundsByPoolId[_poolId] += toInsurancePool;
        // reinsurance pool is pool 0
        fundsByPoolId[0] += reinsuranceReceives;

        console.log("to insurancepool", toInsurancePool);

        IInsurancePool(insurancePools[_poolId]).updateEmissionRate(
            toInsurancePool
        );
        IReinsurancePool(reinsurancePool).updateEmissionRate(
            reinsuranceReceives
        );
    }

    function _approvePoolToken(address _token) internal {
        require(exchange != address(0), "Exchange address not set");
        // approve exchange to swap policy center tokens for deg
        IERC20(_token).approve(exchange, type(uint256).max);
    }
}
