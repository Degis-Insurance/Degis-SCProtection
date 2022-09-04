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

import "../../util/PausableWithoutContext.sol";

import "./PriorityPoolDependencies.sol";
import "./PriorityPoolEventError.sol";
import "./PriorityPoolToken.sol";

import "../../libraries/DateTime.sol";
import "../../libraries/StringUtils.sol";

/**
 * @title Insurance Pool (for single project)
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice Priority pool is used for protecting a specific project
 *         Each priority pool has a maxCapacity (0 ~ 10,000 <=> 0 ~ 100%) that it can cover
 *
 *         When liquidity providers join a priority pool,
 *         they need to transfer their RP_LP token to this insurance pool.
 *
 *         After that, they can share the 45% percent native token reward of this pool.
 *         At the same time, that also means these liquidity will be first liquidated,
 *         when there is an incident happened for this project.
 *
 *         For liquidation process, the pool will first redeem Shield from protectionPool with the staked RP_LP tokens.
 *         If that is enough, no more redeeming.
 *         If still need some liquidity to cover, it will directly transfer part of the protectionPool assets to users.
 *
 *         Most of the functions need to be called through Policy Center:
 *             1) When buying new covers: updateWhenBuy
 *             2) When staking liquidity: stakedLiquidity
 *             3) When unstaking liquidity: unstakedLiquidity
 *             4)
 *
 */
contract PriorityPool is
    PriorityPoolEventError,
    PausableWithoutContext,
    PriorityPoolDependencies
{
    using StringUtils for uint256;
    using DateTimeLibrary for uint256;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Mininum cover amount 10U
    uint256 internal constant MIN_COVER_AMOUNT = 10e6;

    // Max time length in months of granted protection
    uint256 internal immutable maxLength;

    // Min time length in days
    uint256 internal immutable minLength;

    address internal immutable owner;

    // Base premium ratio (max 10000) (260 means 2.6% annually)
    uint256 public immutable basePremiumRatio;

    // Pool id set when deployed
    uint256 public immutable poolId;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Pool name
    string public poolName;

    // Every time there is a report and liquidation, generation += 1
    uint256 public generation;

    // Address of insured token
    address public insuredToken;

    // Max amount of bought protection in shield
    uint256 public maxCapacity;

    // Timestamp of pool creation
    uint256 public startTime;

    // Index for cover amount
    uint256 public coverIndex;

    mapping(uint256 => mapping(uint256 => uint256)) public coverInMonth;

    mapping(uint256 => mapping(uint256 => uint256)) public rewardSpeed;

    // Has already passed the base premium ratio period
    bool internal passedBasePeriod;

    // Generation => crToken address
    mapping(uint256 => address) public crTokenAddress;

    // Generation => lp token address
    mapping(uint256 => address) public lpTokenAddress;

    // Address => Whether is LP address
    mapping(address => bool) internal isLPToken;

    // Generation => Price of lp tokens
    // PRI-LP token amount * Price Index = PRO-LP token amount
    mapping(address => uint256) public priceIndex;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        uint256 _poolId,
        string memory _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _baseRatio,
        address _owner,
        address _weightedFarmingPool,
        address _protectionPool,
        address _policyCenter,
        address _payoutPool
    ) {
        owner = _owner;

        poolId = _poolId;
        poolName = _name;

        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;

        basePremiumRatio = _baseRatio;

        // TODO: change length
        maxLength = 3;
        minLength = 1;

        // Generation 1, price starts from 1 (SCALE)
        priceIndex[_deployNewGenerationLP(_weightedFarmingPool)] = SCALE;

        coverIndex = 10000;

        priorityPoolFactory = msg.sender;
        weightedFarmingPool = _weightedFarmingPool;
        protectionPool = _protectionPool;
        policyCenter = _policyCenter;
        payoutPool = _payoutPool;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyExecutor() {
        if (msg.sender != IPriorityPoolFactory(priorityPoolFactory).executor())
            revert PriorityPool__OnlyExecutor();
        _;
    }

    modifier onlyPolicyCenter() {
        if (msg.sender != policyCenter) revert PriorityPool__OnlyPolicyCenter();
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the current generation PRI-LP token address
     *
     * @return address of Priority Pool LP token
     */
    function currentLPAddress() public view returns (address) {
        return lpTokenAddress[generation];
    }

    /**
     * @notice Cost to buy a cover for a given period of time and amount of tokens
     *
     * @param _amount        Amount being covered (Shield)
     * @param _coverDuration Cover length in month
     */
    function coverPrice(uint256 _amount, uint256 _coverDuration)
        external
        view
        returns (uint256 price, uint256 length)
    {
        require(_amount >= MIN_COVER_AMOUNT, "Under minimum cover amount");

        // Dynamic premium ratio (annually)
        uint256 dynamicRatio = dynamicPremiumRatio(_amount);

        //@audit Rerurn value order change
        (uint256 endTimestamp, , ) = DateTimeLibrary._getExpiry(
            block.timestamp,
            _coverDuration
        );

        // Length in second
        length = endTimestamp - block.timestamp;
        // Price depends on the real timestamp length
        price = (dynamicRatio * _amount * length) / (SECONDS_PER_YEAR * 10000);
    }

    /**
     * @notice Get current active cover amount
     *         Active cover amount = sum of the nearest 3 months' covers
     *
     * @return covered Total active cover amount
     */
    function activeCovered() public view returns (uint256 covered) {
        (uint256 currentYear, uint256 currentMonth, ) = block
            .timestamp
            .timestampToDate();

        // Only count the latest 3 months
        for (uint256 i; i < 3; ) {
            covered += coverInMonth[currentYear][currentMonth];

            unchecked {
                if (++currentMonth > 12) {
                    ++currentYear;
                    currentMonth = 1;
                }

                ++i;
            }
        }

        covered = (covered * coverIndex) / 10000;
    }

    /**
     * @notice Current minimum asset requirement for Protection Pool
     *         Min requirement * capacity ratio = active covered
     */
    function minAssetRequirement() public view returns (uint256) {
        return (activeCovered() * 10000) / maxCapacity;
    }

    /**
     * @notice Get the dynamic premium ratio (annually)
     *         Depends on the covers sold and liquidity amount in all dynamic priority pools
     *         For the first 7 days, use the base premium ratio
     *
     * @param _coverAmount New cover amount (shield) being bought
     *
     * @return ratio The dynamic ratio
     */
    function dynamicPremiumRatio(uint256 _coverAmount)
        public
        view
        returns (uint256 ratio)
    {
        // Time passed since this pool started
        uint256 fromStart = block.timestamp - startTime;

        // First 7 days use base ratio
        // Then use dynamic ratio
        if (fromStart > 7 days) {
            // Covered ratio = Covered amount of this pool / Total covered amount
            uint256 coveredRatio = ((activeCovered() + _coverAmount) * SCALE) /
                (IProtectionPool(protectionPool).getTotalCovered() +
                    _coverAmount);

            address lp = currentLPAddress();
            // LP Token ratio = LP token in this pool / Total lp token
            uint256 tokenRatio = (SimpleERC20(lp).totalSupply() * SCALE) /
                SimpleERC20(protectionPool).totalSupply();

            // Total dynamic pools
            uint256 numofPools = IPriorityPoolFactory(priorityPoolFactory)
                .dynamicPoolCounter();

            // Dynamic premium ratio
            // ( N = total dynamic pools ≤ total pools )
            //
            //                      Covered          1
            //                   --------------- + -----
            //                    TotalCovered       N
            // dynamic ratio =  -------------------------- * base ratio
            //                      LP Amount         1
            //                  ----------------- + -----
            //                   Total LP Amount      N
            //
            ratio =
                (basePremiumRatio * (coveredRatio * numofPools + SCALE)) /
                ((tokenRatio * numofPools) + SCALE);
        } else {
            ratio = basePremiumRatio;
        }
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setMaxCapacity(bool _isUp, uint256 _maxCapacity) external {
        require(msg.sender == owner);

        maxCapacity = _maxCapacity;

        uint256 diff;
        if (_isUp) {
            diff = _maxCapacity - maxCapacity;
        } else {
            diff = maxCapacity - _maxCapacity;
        }

        IPriorityPoolFactory(priorityPoolFactory).updateMaxCapacity(
            _isUp,
            diff
        );
    }

    function setCoverIndex(uint256 _newIndex) external {
        require(msg.sender == protectionPool, "Only protection pool");

        emit CoverIndexChanged(coverIndex, _newIndex);
        coverIndex = _newIndex;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Provide liquidity to priority pool
     *         Only callable through policyCenter
     *         Can not provide new liquidity when paused
     *
     * @param _amount   Amount of liquidity (PRO-LP token) to provide
     * @param _provider Liquidity provider adress
     */
    function stakedLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        onlyPolicyCenter
        returns (address)
    {
        // Check whether this priority pool should be dynamic
        // If so, update it
        _updateDynamic();

        // Mint current generation lp tokens to the provider
        // PRI-LP amount always 1:1 to PRO-LP
        _mintLP(_provider, _amount);
        emit StakedLiquidity(_amount, _provider);

        return currentLPAddress();
    }

    /**
     * @notice Remove liquidity from priority pool
     *         Only callable through policyCenter
     *
     * @param _lpToken  Address of PRI-LP token
     * @param _amount   Amount of liquidity (PRI-LP) to remove
     * @param _provider Provider address
     */
    function unstakedLiquidity(
        address _lpToken,
        uint256 _amount,
        address _provider
    ) external whenNotPaused onlyPolicyCenter {
        if (!isLPToken[_lpToken]) revert PriorityPool__WrongLPToken();

        // Check whether this priority pool should be dynamic
        // If so, update it
        _updateDynamic();

        // Burn PRI-LP tokens and transfer PRO-LP tokens back
        _burnLP(_lpToken, _provider, _amount);
        emit UnstakedLiquidity(_amount, _provider);
    }

    /**
     * @notice Update the record when new policy is bought
     *         Only called from policy center
     *
     * @param _amount          Cover amount (shield)
     * @param _premium         Premium for priority pool
     * @param _length          Cover length (in month)
     * @param _timestampLength Cover length (in second)
     */
    function updateWhenBuy(
        uint256 _amount,
        uint256 _premium,
        uint256 _length,
        uint256 _timestampLength
    ) external whenNotPaused onlyPolicyCenter {
        _updateDynamic();

        // Record cover amount in each month
        _updateCoverInfo(_amount, _length);

        // Update the weighted farming pool speed for this priority pool
        _updateWeightedFarmingSpeed(_length, _premium / _timestampLength);
    }

    /**
     * @notice Pause this pool
     *
     * @param _paused True to pause, false to unpause
     */
    function pausePriorityPool(bool _paused) external {
        if ((msg.sender != owner) && (msg.sender != priorityPoolFactory))
            revert PriorityPool__NotOwnerOrFactory();

        _pause(_paused);
    }

    /**
     * @notice Liquidate pool
     *         Only callable by executor
     *         Only after the report has passed the voting
     *
     * @param _amount Payout amount to be moved out
     */
    function liquidatePool(uint256 _amount) external onlyExecutor {
        _retrievePayout(_amount);

        _updateCurrentLPWeight();

        // Generation ++
        // Deploy the new generation lp token
        // Those who stake liquidity into this priority pool will be given the new lp token
        _deployNewGenerationLP(weightedFarmingPool);

        emit Liquidation(_amount, generation);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Check & update dynamic status of this pool
     *         Record this pool as "already dynamic" in factory
     *
     *         Every time there is a new interaction, will do this check
     */
    function _updateDynamic() internal {
        // Put the cheaper check in the first place
        if (!passedBasePeriod && (block.timestamp - startTime > 7 days)) {
            IPriorityPoolFactory(priorityPoolFactory).updateDynamicPool(poolId);
            passedBasePeriod = true;
        }
    }

    /**
     * @notice Deploy a new generation lp token
     *         Generation starts from 1
     *
     * @return newLPAddress The deployed lp token address
     */
    function _deployNewGenerationLP(address _weightedFarmingPool)
        internal
        returns (address newLPAddress)
    {
        uint256 currentGeneration = ++generation;

        // PRI-LP-2-JOE-G1: First generation of JOE priority pool with pool id 2
        string memory _name = string.concat(
            "PRI-LP-",
            poolId._toString(),
            "-",
            poolName,
            "-G",
            currentGeneration._toString()
        );

        newLPAddress = address(new PriorityPoolToken(_name));
        lpTokenAddress[currentGeneration] = newLPAddress;

        IWeightedFarmingPool(_weightedFarmingPool).addToken(
            poolId,
            newLPAddress,
            priceIndex[newLPAddress]
        );

        isLPToken[newLPAddress] = true;

        emit NewGenerationLPTokenDeployed(
            poolName,
            poolId,
            currentGeneration,
            _name,
            newLPAddress
        );
    }

    /**
     * @notice Mint current generation lp tokens
     *
     * @param _user   User address
     * @param _amount PRI-LP token amount
     */
    function _mintLP(address _user, uint256 _amount) internal {
        // Get current generation lp token address and mint tokens
        address lp = currentLPAddress();
        PriorityPoolToken(lp).mint(_user, _amount);
    }

    /**
     * @notice Burn lp tokens
     *         Need specific generation lp token address as parameter
     *
     * @param _lpToken PRI-LP token adderss
     * @param _user    User address
     * @param _amount  PRI-LP token amount to burn
     */
    function _burnLP(
        address _lpToken,
        address _user,
        uint256 _amount
    ) internal {
        // Transfer PRO-LP token to user
        uint256 proLPAmount = (priceIndex[_lpToken] * _amount) / SCALE;
        SimpleERC20(protectionPool).transfer(_user, proLPAmount);

        // Burn PRI-LP token
        PriorityPoolToken(_lpToken).burn(_user, _amount);
    }

    /**
     * @notice Update cover record info when new covers come in
     *         Record the total cover amount in each month
     *
     * @param _amount Cover amount
     * @param _length Cover length in month
     */
    function _updateCoverInfo(uint256 _amount, uint256 _length) internal {
        (uint256 currentYear, uint256 currentMonth, ) = block
            .timestamp
            .timestampToDate();

        for (uint256 i; i < _length; ) {
            coverInMonth[currentYear][currentMonth] += _amount;

            unchecked {
                if (++currentMonth > 12) {
                    ++currentYear;
                    currentMonth = 1;
                }
                ++i;
            }
        }
    }

    /**
     * @notice Update the farming speed in WeightedFarmingPool
     *
     * @param _length   Length in month
     * @param _newSpeed Speed to be added
     */
    function _updateWeightedFarmingSpeed(uint256 _length, uint256 _newSpeed)
        internal
    {
        uint256[] memory _years = new uint256[](_length);
        uint256[] memory _months = new uint256[](_length);

        (uint256 currentYear, uint256 currentMonth, ) = block
            .timestamp
            .timestampToDate();

        for (uint256 i; i < _length; ) {
            _years[i] = currentYear;
            _months[i] = currentMonth;

            unchecked {
                if (++currentMonth > 12) {
                    ++currentYear;
                    currentMonth = 1;
                }
                ++i;
            }
        }

        IWeightedFarmingPool(weightedFarmingPool).updateRewardSpeed(
            poolId,
            _newSpeed,
            _years,
            _months
        );
    }

    /**
     * @notice Retrieve assets from Protection Pool for payout
     *
     * @param _amount Amount of SHIELD to retrieve
     */
    function _retrievePayout(uint256 _amount) internal {
        // Current PRO-LP amount
        uint256 currentLPAmount = SimpleERC20(protectionPool).balanceOf(
            address(this)
        );

        IProtectionPool proPool = IProtectionPool(protectionPool);

        uint256 proLPPrice = proPool.getLatestPrice();

        // Need how many PRO-LP tokens to cover the _amount
        uint256 neededLPAmount = (_amount * SCALE) / proLPPrice;

        // If current PRO-LP inside priority pool is enough
        // Remove part of the liquidity from Protection Pool
        if (neededLPAmount < currentLPAmount) {
            proPool.removedLiquidity(neededLPAmount, payoutPool);

            priceIndex[currentLPAddress()] =
                ((currentLPAmount - neededLPAmount) * SCALE) /
                currentLPAmount;
        } else {
            uint256 shieldGot = proPool.removedLiquidity(
                currentLPAmount,
                address(this)
            );

            uint256 remainingPayout = _amount - shieldGot;

            proPool.removedLiquidityWhenClaimed(remainingPayout, payoutPool);

            priceIndex[currentLPAddress()] = 0;
        }

        // Set a ratio used when claiming with crTokens
        // E.g. ratio is 1e11
        //      You can only use 10% (1e11 / SCALE) of your crTokens for claiming
        uint256 payoutRatio;
        activeCovered() > 0
            ? payoutRatio = (_amount * SCALE) / activeCovered()
            : payoutRatio = 0;

        IPayoutPool(payoutPool).newPayout(
            poolId,
            generation,
            _amount,
            payoutRatio,
            address(this)
        );
    }

    function _updateCurrentLPWeight() internal {
        address lp = currentLPAddress();

        // Update the farming pool with the new price index
        IWeightedFarmingPool(weightedFarmingPool).updateWeight(
            poolId,
            lp,
            priceIndex[lp]
        );
    }
}
