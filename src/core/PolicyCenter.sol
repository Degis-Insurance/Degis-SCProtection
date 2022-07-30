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

    // bps distribution of premiums 0: treasury, 1: insurance pool, 2: reinsurance pool
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
     * @notice returns pool             info for a given pool id
     * @param _poolId                   pool id generated on Policy Center
     * @return name                     of token pool
     * @return insuredToken             address of token insured by pool
     * @return maxCapacity              of token used by pool
     * @return liqudity                 deposited amount of liquidity in pool
     * @return totalDistributedReward   of tokens used by pool
     */
    function getPoolInfo(uint256 _poolId)
        public
        view
        poolExists(_poolId)
        returns (
            string memory,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        (
            string memory name,
            address insuredToken,
            uint256 maxCapacity,
            uint256 liquidity,
            uint256 totalDistributedReward
        ) = IInsurancePool(insurancePools[_poolId]).poolInfo();
        return (
            name,
            insuredToken,
            maxCapacity,
            liquidity,
            totalDistributedReward
        );
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
                    liquidity.userDebt,
                    _provider
                );
        } else {
            return
                // gets reward from reinsurance pool
                IReinsurancePool(reinsurancePool).calculateReward(
                    liquidity.amount,
                    liquidity.userDebt,
                    _provider
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
     * @param _token address of token that a pool negotiates in
     * @param _poolId id of the pool
     */
    function setTokenByPoolId(address _token, uint256 _poolId) external {
        require(
            msg.sender == owner() || msg.sender == insurancePoolFactory,
            "Only owner or insurancePoolFactory can set tokens"
        );
        // maps address to pool id
        tokenByPoolId[_poolId] = _token;
        // approve token swapping for internal fudns management
        _approvePoolToken(_token);
    }

     /**
     * @notice registers a new insurance pool deployed by pool factory
     * @param _poolId   pool id generated on Policy Center
     * @param _address  address of the insurance pool
     */
    function setPoolId(uint256 _poolId, address _address) external {
        require(
            msg.sender == insurancePoolFactory,
            "not requested by Insurance Pool Factory"
        );
        insurancePools[_poolId] = _address;
    }

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
        Coverage storage coverage = coverages[_poolId][msg.sender];
        coverage.amount += _coverAmount;
        // initial 7 days buffer so pool cannot be exploited
        coverage.buyDate = block.timestamp + 7 days;
        coverage.length = _length;
        // updates pool distribution based on paid amount
        IInsurancePool(insurancePools[_poolId]).updatePoolDistribution(_pay);
        IERC20(tokenByPoolId[_poolId]).transferFrom(
            msg.sender,
            address(this),
            price
        );
        _splitPremium(_poolId, _pay);
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

        IERC20(tokenByPoolId[_poolId]).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
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
        // claim rewards for caller by pool id. user debt is updated in claim reward
        _claimReward(_poolId, msg.sender);
        // removes liquidity from insurance or reinsurance pool
        liquidityByPoolId[_poolId] -= _amount;

        // new amount owned by caller
        uint256 newAmount = liquidity.amount - _amount;
        liquidity.amount = newAmount;
        liquidity.lastClaim = block.timestamp;
        uint256 totalSupply;
        // transfer rewards
        if (_poolId == 0) {
            IReinsurancePool pool = IReinsurancePool(reinsurancePool);
            // updates user debt based on accumulated rewards per share
            liquidity.userDebt =
                liquidity.amount *
                pool.accumulatedRewardPerShare();
            totalSupply = pool.totalSupply();
            // burns tokens owner by caller
            pool.removeLiquidity(_amount, msg.sender);
        } else {
            IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
            // updates user debt based on accumulated rewards per share
            liquidity.userDebt =
                liquidity.amount *
                pool.accumulatedRewardPerShare();
            totalSupply = pool.totalSupply();
            // burns tokens owner by caller
            pool.removeLiquidity(_amount, msg.sender);
        }
        // calculates amount to transfer to caller in native token
        uint256 amountToTransfer = (liquidityByPoolId[_poolId] / totalSupply) *
            _amount;
        // transfers tokens used to provide liquidity
        IERC20(tokenByPoolId[_poolId]).transfer(msg.sender, amountToTransfer);
    }

    /**
     * @notice claims liquidation payout given a pool id
     * @param _poolId pool id generated on Policy Center
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
        // so that people that were covered during report process are covered
        require(
            coverage.buyDate + (coverage.length * 1 days) >=
                pool.endLiquidationDate() - 20 days,
            "coverage has expired"
        );
        require(coverage.amount > 0, "no coverage to claim");
        // gets amount to give as payout
        uint256 amount = calculatePayout(_poolId, msg.sender);
        console.log(amount);
        // registers removal of funds from pool
        fundsByPoolId[_poolId] -= coverage.amount;
        // coverage by user is removed
        coverage.amount = 0;
        if (fundsByPoolId[_poolId] >= amount) {
            IERC20(tokenByPoolId[_poolId]).transfer(msg.sender, amount);
        } else {
            // transfer the totalSupply to user and then ask Reinsurance pool for the remainder
            IERC20(tokenByPoolId[_poolId]).transfer(
                msg.sender,
                fundsByPoolId[_poolId]
            );
            _reinsurePool(amount - fundsByPoolId[_poolId], msg.sender, tokenByPoolId[_poolId]);
        }
        emit Payout(amount, msg.sender);
    }

    /**
     * @notice rewards reporter when a reported insurance pool is liquidated with treasury
     * callable by contract only
     * @param _reporter address of the reporter
     */
    function rewardTreasuryToReporter(address _reporter) external {
        require(msg.sender == proposalCenter, "not requested by Executor");
        // 10% of treasury + 2000 DEG
        uint256 reward = (treasury * 1000) / 10000;
        treasury -= reward;

        IERC20(deg).transfer(_reporter, reward);
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
        }
        Liquidity storage liquidity = liquidities[_poolId][_provider];
        uint256 reward = (liquidity.amount *
            IInsurancePool(insurancePools[_poolId])
                .accumulatedRewardPerShare()) - liquidity.userDebt;
        if (reward == 0) {
            liquidity.userDebt =
                liquidity.amount *
                IInsurancePool(insurancePools[_poolId])
                    .accumulatedRewardPerShare();
            return;
        }
        IERC20(tokenByPoolId[_poolId]).transfer(_provider, reward);
    }

    /**
     * @notice swaps tokens for deg
     * 
     * @param _amount       amount to swap for degis
     * @param _fromToken    token address to exchange from
     * @param _toToken      token address to exchange to
     */
    function _swapTokens(uint256 _amount, address _fromToken, address _toToken)
        internal
        returns (uint256 receives)
    {
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
     * @param _amount       amount of liquidity to request
     * @param _fromToken    token address to exchange from
     * @param _toToken      token address to exchange to
     */
    function _swapForExactTokens(uint256 _amount, address _fromToken, address _toToken)
        internal
        returns (uint256 receives)
    {
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
        uint256 treasuryReceives = _swapTokens(toTreasury,fromToken, deg);
        uint256 reinsuranceReceives = _swapTokens(toReinsurancePool, fromToken, deg);
        treasury += treasuryReceives;
        totalRewardsByPoolId[_poolId] += toInsurancePool;
        // reinsurance pool is pool 0
        totalRewardsByPoolId[0] += reinsuranceReceives;
    }

    function _approvePoolToken(address _token) internal {
        require(exchange != address(0), "Exchange address not set");
        // approve exchange to swap policy center tokens for deg
        IERC20(_token).approve(exchange, type(uint256).max);
    }

    /**
    @notice provides liquidity to pools in need of it. Only callable by Pools
     *
    @param _amount      token being insured
    @param _insured    address of the insured user
    @param _token     address of covered wallet
    */
    function _reinsurePool(uint256 _amount, address _insured, address _token) internal {
        require(_amount > 0, "amount should be greater than 0");
        // msg.sender is the pool address, use it as reference to the pool info
        liquidityByPoolId[0] -= _amount;
        // swap tokens for deg
        _swapForExactTokens(_amount, deg, _token);
        
        IERC20(_token).transfer(_insured, _amount);
    }
}
