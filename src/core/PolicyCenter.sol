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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IInsurancePoolFactory.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";
import "../util/Setters.sol";

import "forge-std/console.sol";

/**
 * @title Policy Center
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the policy center for degis smart contract insurance
 *         Users can buy policies and get payoff here
 *         Sellers can provide liquidity and choose the pools to cover
 *
 */
contract PolicyCenter is Ownable, Setters {
    struct Coverage {
        uint256 amount;
        uint256 buyDate;
        uint256 length;
    }

    struct Liquidity {
        uint256 amount;
        uint256 userDebt;
        uint256 lastClaim;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // productIds => address, updated once pools are deployed
    // ReinsurancePool is pool 0
    mapping(uint256 => address) public insurancePools;

    mapping(uint256 => mapping(address => Coverage)) public coverages;
    mapping(uint256 => uint256) public fundsByPoolId;

    mapping(uint256 => mapping(address => Liquidity)) public liquidities;
    mapping(uint256 => uint256) public liquidityByPoolId;
    // totalRewards by pool id
    mapping(uint256 => uint256) public totalRewardsByPoolId;

    uint256[3] public premiumSplits;
    // amount in shield
    uint256 public treasury;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Reward(uint256 _amount, address _address);
    event Payout(uint256 _amount, address _address);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(address _reinsurancePool) {
        insurancePools[0] = _reinsurancePool;
        reinsurancePool = _reinsurancePool;
        // 5 % to treasury, 45% to insurance, 50% to reinsurance 0.03% to splitter
        premiumSplits = [500, 4500, 5000];
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier poolExists(uint256 _poolId) {
        require(insurancePools[_poolId] != address(0), "Pool not found");
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @dev returns premium split used by Policy Center
     */
    function getPremiumSplits()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (premiumSplits[0], premiumSplits[1], premiumSplits[2]);
    }

    /**
     * @dev returns pool info for a given pool id
     * @param _poolId pool id generated on Policy Center
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
     * @dev returns true if given pool address is a valid pool
     * @param _poolAddress pool address
     */
    function isPoolAddress(address _poolAddress) public view returns (bool) {
        uint256 length = IInsurancePoolFactory(insurancePoolFactory)
            .getPoolCounter();
        for (uint256 i = 0; i < length; i++) {
            if (insurancePools[i] == _poolAddress) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev returns insurance pool address given a pool id
     * @param _poolId pool id generated on Policy Center
     */
    function getInsurancePoolById(uint256 _poolId)
        public
        view
        returns (address)
    {
        return insurancePools[_poolId];
    }

    /**
    @dev returns information about the coverage of a given user
    @param _poolId address of the covered wallet
    @return _covered address of covered wallet
    @return buyDate 0 if no coverage
    @return length 0 if no coverage
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
     * @dev returns reward to liquidity providers
     * @param _poolId pool id to claim from. 0 if reinsurance pool
     */
    function calculateReward(uint256 _poolId, address _provider)
        public
        view
        poolExists(_poolId)
        returns (uint256)
    {
        Liquidity memory liquidity = liquidities[_poolId][_provider];
        if (_poolId > 0) {
            return
                IInsurancePool(insurancePools[_poolId]).calculateReward(
                    liquidity.amount,
                    liquidity.userDebt,
                    _provider
                );
        } else {
            return
                IReinsurancePool(reinsurancePool).calculateReward(
                    liquidity.amount,
                    liquidity.userDebt,
                    _provider
                );
        }
    }

    function calculatePayout(uint256 _poolId, address _insured)
        public
        view
        returns (uint256)
    {
        require(_poolId > 0, "Reinsurance pool grants no direct payout");
        uint256 amount = coverages[_poolId][_insured].amount;
        return amount;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @dev sets the premium splits used by Policy Center
     * @param _treasury split for treasury
     * @param _insurance split for insurance
     * @param _reinsurance split for reinsurance
     */
    function setPremiumSplit(
        uint256 _treasury,
        uint256 _insurance,
        uint256 _reinsurance
    ) external onlyOwner {
        // should sum up to 100% and reward up to 1%
        require(
            _treasury + _insurance + _reinsurance == 10000,
            "Invalid split"
        );
        require(_treasury > 0, "has not given a treasury split");
        require(_insurance > 0, "has not given an insurance split");
        require(_reinsurance > 0, "has not given a reinsurance split");
        premiumSplits = [_treasury, _insurance, _reinsurance];
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Buy new coverage for a given pool
     * @param _poolId pool id generated on Policy Center
     * @param _pay amount paid to cover amount of tokens
     * @param _coverAmount amount of tokens to cover
     * @param _length lenght of coverage in days
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
        // TODO
        require(
            IInsurancePool(insurancePools[_poolId]).maxCapacity() >=
                _pay + fundsByPoolId[_poolId],
            "exceeds max capacity"
        );
        uint256 price = IInsurancePool(insurancePools[_poolId]).coveragePrice(
            _coverAmount,
            _length
        );
        require(price == _pay, "pay does not correspond to price");
        _splitPremium(_poolId, _pay);
        //register coverage
        Coverage storage coverage = coverages[_poolId][msg.sender];
        coverage.amount += _coverAmount;
        coverage.buyDate = block.timestamp;
        coverage.length = _length;

        IInsurancePool(insurancePools[_poolId]).registerNewCoverage(_pay);
        IERC20(shield).transferFrom(msg.sender, address(this), price);
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
        uint256 totalSplit = _amount;
        uint256 toTreasury = (totalSplit * premiumSplits[0]) / 10000;
        uint256 toPool = (totalSplit * premiumSplits[1]) / 10000;
        uint256 toReinusrancePool = (totalSplit * premiumSplits[2]) / 10000;

        treasury += toTreasury;
        fundsByPoolId[_poolId] += toPool;
        // reinsurance pool is pool 0
        fundsByPoolId[0] += toReinusrancePool;
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
        // claim rewards
        _claimReward(_poolId, msg.sender);
        // adds liquidity to insurance or reinsurance pool
        liquidityByPoolId[_poolId] += _amount;
        Liquidity storage liquidity = liquidities[_poolId][msg.sender];
        if (_poolId > 0) {
            IInsurancePool(insurancePools[_poolId]).provideLiquidity(
                _amount,
                msg.sender
            );
        } else {
            IReinsurancePool(reinsurancePool).provideLiquidity(
                _amount,
                msg.sender
            );
        }
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
            _amount <= liquidityByPoolId[_poolId],
            "Amount must be less than liquidity"
        );
        require(
            _amount <= liquidities[_poolId][msg.sender].amount,
            "Amount must be less than provided liquidity"
        );
        require(
            block.timestamp >=
                liquidities[_poolId][msg.sender].lastClaim + 604800,
            "cannot remove liquidity within 7 days of last claim"
        );

        Liquidity storage liquidity = liquidities[_poolId][msg.sender];
        // claim rewards
        _claimReward(_poolId, msg.sender);
        // adds liquidity to insurance or reinsurance pool
        liquidityByPoolId[_poolId] -= _amount;
        uint256 newAmount = liquidity.amount - _amount;
        liquidity.amount = newAmount;
        liquidity.lastClaim = block.timestamp;
        uint256 totalSupply;
        // transfer rewards
        if (_poolId == 0) {
            IReinsurancePool pool = IReinsurancePool(reinsurancePool);
            liquidity.userDebt =
                liquidity.amount *
                pool.accumulatedRewardPerShare();
            totalSupply = pool.totalSupply();
            pool.removeLiquidity(_amount, msg.sender);
        } else {
            IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
            liquidity.userDebt =
                liquidity.amount *
                pool.accumulatedRewardPerShare();
            totalSupply = pool.totalSupply();
            pool.removeLiquidity(_amount, msg.sender);
        }
        uint256 amountToTransfer = (liquidityByPoolId[_poolId] / totalSupply) *
            _amount;
        IERC20(shield).transfer(msg.sender, amountToTransfer);
    }

    /**
     * @notice claims liquidation payout given a pool id
     * @param _poolId pool id generated on Policy Center
     */
    function claimPayout(uint256 _poolId) public poolExists(_poolId) {
        require(_poolId > 0, "PoolId must be greater than 0");
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        Coverage storage coverage = coverages[_poolId][msg.sender];

        require(pool.liquidated(), "pool is not claimable");
        require(
            pool.endLiquidationDate() <= block.timestamp,
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
        uint256 amount = calculatePayout(_poolId, msg.sender);
        fundsByPoolId[_poolId] -= coverage.amount;
        coverage.amount = 0;
        if (pool.totalSupply() >= amount) {
            IERC20(shield).transfer(msg.sender, amount);
        } else {
            // transfer the totalSupply to user and then ask Reinsurance pool for the remainder
            IERC20(shield).transfer(msg.sender, pool.totalSupply());
            _requestReinsurance(amount - pool.totalSupply(), msg.sender);
        }
        emit Payout(amount, msg.sender);
    }

    /**
     * @notice registers a new insurance pool deployed by pool factory
     * @param _poolId pool id generated on Policy Center
     * @param _address address of the insurance pool
     */
    function addPoolId(uint256 _poolId, address _address) external {
        require(
            msg.sender == insurancePoolFactory,
            "not requested by Insurance Pool Factory"
        );
        insurancePools[_poolId] = _address;
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
        IERC20(shield).transfer(_reporter, reward);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice claims rewards from a given pool id
     * @param _poolId pool id to claim rewards from
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
        IERC20(shield).transfer(_provider, reward);
    }

    /**
     * @notice requests reinsurance from Reinsurance Pool
     * @param _amount amount of liquidity to request
     * @param _address address of the claimer
     */
    function _requestReinsurance(uint256 _amount, address _address) internal {
        IReinsurancePool(reinsurancePool).reinsurePool(_amount, _address);
    }
}
