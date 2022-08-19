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
import "../../util/OwnableWithoutContext.sol";

import "./PriorityPoolDependencies.sol";
import "./PriorityPoolEventError.sol";
import "./PriorityPoolToken.sol";

import "../../interfaces/IPremiumRewardPool.sol";

import "../../libraries/DateTime.sol";
import "../../libraries/StringUtils.sol";

import "forge-std/console.sol";

/**
 * @title Insurance Pool (for single project)
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice Priority pool is used for protecting a specific project
 *         Each priority pool has a maxCapacity (0 ~ 100%) that it can cover
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
 */
contract PriorityPool is
    PriorityPoolEventError,
    OwnableWithoutContext,
    PausableWithoutContext,
    PriorityPoolDependencies
{
    using StringUtils for uint256;
    using DateTimeLibrary for uint256;
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Time users have to claim payout when pool is liquidated
    uint256 public constant CLAIM_PERIOD = 30;

    // Mininum cover amount 10U
    uint256 public constant MIN_COVER_AMOUNT = 10e6;

    // Max time length in months of granted protection
    uint256 public immutable maxLength;

    // Min time length in days
    uint256 public immutable minLength;

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

    // If the pool has been liquidated
    bool public liquidated;

    // Max amount of bought protection in shield
    uint256 public maxCapacity;

    // Timestamp of pool creation
    uint256 public startTime;

    mapping(uint256 => mapping(uint256 => uint256)) public coverInMonth;

    mapping(uint256 => mapping(uint256 => uint256)) public rewardSpeed;

    // Has already passed the base premium ratio period
    bool public passedBasePeriod;

    // Generation => crToken address
    mapping(uint256 => address) public crTokenAddress;

    // Generation => lp token address
    mapping(uint256 => address) public lpTokenAddress;

    mapping(address => bool) public isLPToken;

    // Index for cover amount
    uint256 public coverIndex;

    // Generation => Price of lp tokens 
    mapping(uint256 => uint256) public priceIndex;

    // Sum of total lp supply (including different generations)
    uint256 public totalLPSupply;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _poolName,
        uint256 _baseRatio,
        address _admin,
        uint256 _poolId
    ) OwnableWithoutContext(_admin) {
        // token address insured by pool
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;

        basePremiumRatio = _baseRatio;

        poolId = _poolId;
        poolName = _poolName;

        // TODO: change length
        maxLength = 3;
        minLength = 1;

        // Generation 0, price starts from 1
        priceIndex[0] = SCALE;

        _deployNewGenerationLP(_poolName, _poolId);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyExecutor() {
        require(msg.sender == executor, "Only executor can call this function");
        _;
    }

    modifier onlyPolicyCenter() {
        require(
            msg.sender == policyCenter,
            "Only policy center can call this function"
        );
        _;
    }

    modifier whenNotLiquidated() {
        require(!liquidated, "Liquidated");
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function currentLPAddress() public view returns (address) {
        return lpTokenAddress[generation];
    }

    /**
     * @notice Cost to buy a cover for a given period of time and amount of tokens
     *
     * @param _amount        Amount being covered
     * @param _coverDuration Cover length in month
     */
    function coverPrice(uint256 _amount, uint256 _coverDuration)
        external
        view
        returns (uint256 price, uint256 length)
    {
        require(_amount >= MIN_COVER_AMOUNT, "Under minimum cover amount");

        uint256 dynamicRatio = dynamicPremiumRatio(_amount);

        uint256 endTimestamp = _getExpiry(block.timestamp, _coverDuration);

        length = endTimestamp - block.timestamp;
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
    }

    /**
     * @notice Current minimum asset requirement for Protection Pool
     */
    function minAssetRequirement() public view returns (uint256) {
        return (activeCovered() * 100) / maxCapacity;
    }

    /**
     * @notice Get the dynamic premium ratio (annually)
     *         Depends on the covers sold and liquidity amount
     *         For the first 48 hours, use the base premium ratio
     *
     * @param _coverAmount New cover amount being bought
     *
     * @return ratio The dynamic ratio
     */
    function dynamicPremiumRatio(uint256 _coverAmount)
        public
        view
        returns (uint256 ratio)
    {
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
            uint256 tokenRatio = (IERC20(lp).totalSupply() * SCALE) /
                IERC20(protectionPool).totalSupply();

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

    function setMaxCapacity(uint256 _maxCapacity) external onlyOwner {
        maxCapacity = _maxCapacity;
    }

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    function setIncidentReport(address _incidentReport) external onlyOwner {
        _setIncidentReport(_incidentReport);
    }

    function setPremiumRewardPool(address _premiumRewardPool)
        external
        onlyOwner
    {
        _setPremiumRewardPool(_premiumRewardPool);
    }

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        _setPolicyCenter(_policyCenter);
    }

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        onlyOwner
    {
        _setPriorityPoolFactory(_priorityPoolFactory);
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
     *         Can not provide new liquidity when liquidated / paused
     *
     * @param _amount   Amount of liquidity (PRO-LP token) to provide
     * @param _provider Liquidity provider adress
     */
    function stakedLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        whenNotLiquidated
        onlyPolicyCenter
    {
        // Check whether this priority should be dynamic
        // If so, update it
        _updateDynamic();

        // Mint current generation lp tokens to the provider
        _mintLP(_provider, _amount);
        emit LiquidityProvision(_amount, _provider);
    }

    /**
     * @notice Remove liquidity from insurance pool
     *         Only callable through policyCenter
     *
     * @param _lpToken  Address of lp token
     * @param _amount   Amount of liquidity (current generation lp) to remove
     * @param _provider Provider address
     */
    function unstakedLiquidity(
        address _lpToken,
        uint256 _amount,
        address _provider
    ) external whenNotPaused whenNotLiquidated onlyPolicyCenter {
        require(isLPToken[_lpToken], "Wrong lp token");

        _updateDynamic();

        // Burn current genration lp tokens to the provider
        _burnLP(_lpToken, _provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
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
    ) external whenNotPaused whenNotLiquidated onlyPolicyCenter {
        _updateDynamic();

        // Record cover amount in each month
        _updateCoverInfo(_amount, _length);

        // Update the weighted farming pool speed for this priority pool
        _updateWeightedFarmingSpeed(_length, _premium / _timestampLength);
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
     * @notice Pause this pool
     *
     * @param _paused True to pause, false to unpause
     */
    function pausePriorityPool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == incidentReport),
            "Only owner or Incident Report can call this function"
        );

        _pause(_paused);
    }

    /**
     * @notice Sets this insurance pool status to liquidated
     *         Only callable by executor
     *         Only after the report has passed the voting
     *
     * @param _amount Payout amount to be moved out
     */
    function liquidatePool(uint256 _amount) external onlyExecutor {
        // Change the status of the insurance pool to liquidated and allows payout claims
        _setLiquidationStatus(true);

        // Deploy new lp tokens
        _deployNewGenerationLP(poolName, poolId);

        // Set end liquidation date
        // Users will have CLAIM_PERIOD days to claim payout.
        endLiquidationDate = block.timestamp + CLAIM_PERIOD * 1 days;

        _retrievePayout(_amount);

        emit Liquidation(_amount, endLiquidationDate);
    }

    /**
     * @notice Retrieve assets from Protection Pool for payout
     *
     * @param _amount Amount of SHIELD to retrieve
     */
    function _retrievePayout(uint256 _amount) internal {
        // Current lp amount
        uint256 currentLP = IERC20(protectionPool).balanceOf(address(this));

        address shield = IPriorityPoolFactory(priorityPoolFactory).shield();

        uint256 price = IERC20(shield).balanceOf(protectionPool) /
            IERC20(protectionPool).totalSupply();

        uint256 neededLPAmount = (_amount * SCALE) / price;

        address payoutPool = IPriorityPoolFactory(priorityPoolFactory)
            .payoutPool();

        uint256 totalPayout;

        // If the shield from current lp is enough
        if (neededLPAmount < currentLP) {
            totalPayout = IProtectionPool(protectionPool).removedLiquidity(
                neededLPAmount,
                payoutPool
            );
        } else {
            uint256 shieldGot = IProtectionPool(protectionPool)
                .removedLiquidity(currentLP, address(this));

            uint256 remainingPayout = _amount - shieldGot;

            IProtectionPool(protectionPool).removedLiquidityWhenClaimed(
                remainingPayout,
                payoutPool
            );

            totalPayout = remainingPayout + shieldGot;
        }

        // Set a ratio used when claiming with crTokens
        // E.g. ratio is 1e11
        //      You can only use 10% (1e11 / SCALE) of your crTokens for claiming
        uint256 payoutRatio = (_amount * SCALE) / activeCovered();

        IPayoutPool(payoutPool).newPayout(_amount, payoutRatio);
    }

    /**
     * @notice End the liquidation period
     *         Users can redeem remaining capacity when ending liquidation
     */
    function endLiquidation() external {
        require(liquidated, "Pool has not been liquidated");
        require(
            block.timestamp > endLiquidationDate,
            "Pool has not ended liquidation"
        );

        // liquidation has ended. payout claims cannot be made.
        _setLiquidationStatus(false);

        emit LiquidationEnded(block.timestamp);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Deploy a new generation lp token
     *         Generation starts from 0
     *
     * @param _poolName Pool name
     * @param _poolId   Pool id
     *
     * @return newLPAddress The deployed lp token address
     */
    function _deployNewGenerationLP(string memory _poolName, uint256 _poolId)
        internal
        returns (address newLPAddress)
    {
        uint256 currentGeneration = generation++;

        // PRI-LP-2-JOE-G1: First generation of JOE priority pool with pool id
        string memory _name = string.concat(
            "PRI-LP-",
            _poolId._toString(),
            "-",
            _poolName,
            "-G",
            currentGeneration._toString()
        );

        address newLP = address(new PriorityPoolToken(_name));

        lpTokenAddress[currentGeneration] = newLP;
        isLPToken[newLP] = true;

        emit NewGenerationLPTokenDeployed(
            _poolName,
            _poolId,
            currentGeneration,
            _name,
            newLPAddress
        );
    }

    /**
     * @notice Mint current generation lp tokens
     *
     * @param _user   User address
     * @param _amount LP token amount
     */
    function _mintLP(address _user, uint256 _amount) internal {
        // Get current generation lp token address and mint tokens
        address lp = currentLPAddress();
        IPriorityPoolToken(lp).mint(_user, _amount);

        totalLPSupply += _amount;
    }

    /**
     * @notice Burn lp tokens
     *         Need specific generation lp token address as parameter
     *
     * @param _lpToken LP token adderss
     * @param _user    User address
     * @param _amount  LP token amount
     */
    function _burnLP(
        address _lpToken,
        address _user,
        uint256 _amount
    ) internal {
        uint256 proLPAmount = (priceIndex * _amount) / SCALE;

        IERC20(protectionPool).transfer(_user, proLPAmount);

        IPriorityPoolToken(_lpToken).burn(_user, _amount);
        totalLPSupply -= _amount;
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
     * @notice Set liquidation status
     */
    function _setLiquidationStatus(bool _liquidated) internal {
        liquidated = _liquidated;
    }

    /**
     * @notice Get the expiry timestamp based on cover duration
     *
     * @param _now           Current timestamp
     * @param _coverDuration Months to cover: 1-3
     */
    function _getExpiry(uint256 _now, uint256 _coverDuration)
        internal
        pure
        returns (uint256)
    {
        // Get the day of the month
        (, , uint256 day) = _now.timestampToDate();

        // Cover duration of 1 month means current month
        // unless today is the 25th calendar day or later
        uint256 monthsToAdd = _coverDuration - 1;

        if (day >= 25) {
            // Add one month
            monthsToAdd += 1;
        }

        return _getFutureMonthEndTime(_now, monthsToAdd);
    }

    /**
     * @notice Get the end timestamp of a future month
     *
     * @param _timestamp   Current timestamp
     * @param _monthsToAdd Months to be added
     *
     * @return endTimestamp End timestamp of a future month
     */
    function _getFutureMonthEndTime(uint256 _timestamp, uint256 _monthsToAdd)
        private
        pure
        returns (uint256 endTimestamp)
    {
        uint256 futureTimestamp = _timestamp.addMonths(_monthsToAdd);

        endTimestamp = _getMonthEndTimestamp(futureTimestamp);
    }

    /**
     * @notice Get the last second of a month
     *
     * @param _timestamp Timestamp to be calculated
     *
     * @return endTimestamp End timestamp of the month
     */
    function _getMonthEndTimestamp(uint256 _timestamp)
        private
        pure
        returns (uint256 endTimestamp)
    {
        // Get the year and month from the date
        (uint256 year, uint256 month, ) = _timestamp.timestampToDate();

        // Count the total number of days of that month and year
        uint256 daysInMonth = year._getDaysInMonth(month);

        // Get the month end timestamp
        endTimestamp = DateTimeLibrary.timestampFromDateTime(
            year,
            month,
            daysInMonth,
            23,
            59,
            59
        );
    }

    function _updatePriceIndex() internal {
        priceIndex =
            (IERC20(protectionPool).balanceOf(address(this)) * SCALE) /
            totalLPSupply;
    }
}
