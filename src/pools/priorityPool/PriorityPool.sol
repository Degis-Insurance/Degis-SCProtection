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

import "src/pools/priorityPool/PriorityPool.sol";
import "../../interfaces/IPremiumRewardPool.sol";

import "../../libraries/DateTime.sol";

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
    ERC20,
    OwnableWithoutContext,
    PausableWithoutContext,
    PriorityPoolDependencies
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Time users have to claim payout when pool is liquidated
    uint256 public constant CLAIM_PERIOD = 30;

    uint256 public constant MIN_COVER_AMOUNT = 1 ether;

    // Max time length in days of granted protection
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

    // Accumulated reward per lp token
    uint256 public accumulatedRewardPerShare;

    uint256 public lastRewardTimestamp;

    uint256 public emissionEndTime;

    uint256 public emissionRate;

    uint256 public endLiquidationDate;

    mapping(uint256 => mapping(uint256 => uint256)) public coverInMonth;

    mapping(uint256 => mapping(uint256 => uint256)) public rewardSpeed;

    address public premiumRewardPool;

    // Has already passed the base premium ratio period
    bool public passedBasePeriod;

    // Generation => crToken address
    mapping(uint256 => address) public crTokenAddress;

    // Generation => lp token address
    mapping(uint256 => address) public lpTokenAddress;

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

        // TODO: change length
        maxLength = 3;
        minLength = 1;

        _deployNewGeneration(_poolName, _poolId);
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

    /**
     * @notice Cost to buy a cover for a given period of time and amount of tokens
     *
     * @param _amount Amount being covered
     * @param _length Cover length in month
     */
    function coverPrice(uint256 _amount, uint256 _length)
        external
        view
        returns (uint256 price, uint256 length)
    {
        require(_amount >= MIN_COVER_AMOUNT, "Under minimum cover amount");
        require(_withinLength(_length), "Wrong cover length");

        uint256 dynamicRatio = dynamicPremiumRatio(_amount);

        uint256 endTimestamp = getExpiryDateInternal(block.timestamp, _length);
        length = endTimestamp - block.timestamp;

        price = (dynamicRatio * _amount * length) / (SECONDS_PER_YEAR * 10000);
    }

    /**
     * @notice Get current active cover amount
     *
     * @return covered Total active cover
     */
    function activeCovered() public view returns (uint256 covered) {
        (uint256 currentYear, uint256 currentMonth, ) = DateTimeLibrary
            .timestampToDate(block.timestamp);

        for (uint256 i; i < 3; ) {
            covered += coverInMonth[currentYear][currentMonth];

            unchecked {
                if (++currentMonth == 12) {
                    ++currentYear;
                    currentMonth = 1;
                }

                ++i;
            }
        }
    }

    /**
     * @notice Get the dynamic premium ratio (annually)
     *         Depends on the covers sold and liquidity amount
     *         For the first 48 hours, use the base premium ratio
     *
     * @param _newAmount New cover amount being bought
     *
     * @return ratio The dynamic ratio
     */
    function dynamicPremiumRatio(uint256 _newAmount)
        public
        view
        returns (uint256 ratio)
    {
        uint256 fromStart = block.timestamp - startTime;

        // First 7 days use base ratio
        // Then use dynamic ratio
        if (fromStart > 7 days) {
            // Covered ratio = Covered amount of this pool / Total covered amount
            uint256 coveredRatio = ((activeCovered() + _newAmount) * SCALE) /
                IProtectionPool(protectionPool).getTotalCovered();

            // LP Token ratio = LP token in this pool / Total lp token
            uint256 tokenRatio = (totalSupply() * SCALE) /
                IERC20(protectionPool).totalSupply();

            uint256 numofPools = IPriorityPoolFactory(priorityPoolFactory)
                .dynamicPoolCounter();

            // Dynamic premium ratio
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

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        _setPolicyCenter(_policyCenter);
    }

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        onlyOwner
    {
        _setPriorityPoolFactory(_priorityPoolFactory);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Provide liquidity to priority pool
     *         Only callable through policyCenter
     *         Can not provide new liquidity when liquidated / paused
     *
     * @param _amount   Amount of liquidity to provide
     * @param _provider Liquidity provider adress
     */
    function stakedLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        whenNotLiquidated
        onlyPolicyCenter
    {
        _updateDynamic();
        // require(_amount + totalSupply() <= maxCapacity, "Exceed max capacity");

        // Mint lp tokens to the provider
        _mint(_provider, _amount);
        emit LiquidityProvision(_amount, _provider);
    }

    /**
     * @notice Remove liquidity from insurance pool
     *         Only callable through policyCenter
     *
     * @param _amount   Amount of liquidity to remove
     * @param _provider Provider address
     */
    function unstakedLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        whenNotLiquidated
        onlyPolicyCenter
    {
        _updateDynamic();
        // require(_amount + totalSupply() <= maxCapacity, "Exceed max capacity");

        require(_amount > 0, "amount should be greater than 0");
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
    }

    function updateWhenBuy(uint256 _amount, uint256 _length)
        external
        whenNotPaused
        whenNotLiquidated
        onlyPolicyCenter
    {
        _updateCoverInfo(_amount, _length);
        // coverInMonth[]
        _updateDynamic();
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
     * @notice Called when liqudity is provided, removed or coverage is bought.
     *         updates all state variables to reflect current reward emission.
     */
    function updateRewards() public onlyPolicyCenter {
        _updateRewards();
    }

    /**
     * @notice Sets this insurance pool status to liquidated
     *         Only callable by executor
     *         Only after the report has passed the voting
     *
     * @param _amount Payout amount to be moved out
     */
    function liquidatePool(uint256 _amount) external onlyExecutor {
        // changes the status of the insurance pool to liquidated and allows payout claims
        _setLiquidationStatus(true);

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
            totalSupply();

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

    function _deployNewGeneration(string calldata _poolName, uint256 _poolId)
        internal
    {
        uint256 currentGeneration = generation++;
        string memory _name = string.concat(
            "PRI-LP-",
            _toString(_poolId),
            "-",
            _poolName,
            _toString(currentGeneration)
        );
        address newLPAddress = new PriorityPoolToken(_name);

        emit NewGenerationLPTokenDeployed(_poolName, _poolId, currentGeneration, newLPAddress);
    }

    /**
     * @notice Update cover record info when new covers come in
     *
     * @param _amount Cover amount
     * @param _length Cover length
     */
    function _updateCoverInfo(uint256 _amount, uint256 _length) internal {
        (
            uint256 currentYear,
            uint256 currentMonth,
            uint256 currentDay
        ) = DateTimeLibrary.timestampToDate(block.timestamp);

        if (currentDay >= 25) ++_length;

        for (uint256 i; i < _length; ) {
            coverInMonth[currentYear][currentMonth + i] += _amount;
        }
    }

    /**
     * @notice Update dynamic status of this pool
     *         Record this pool as "already dynamic" in factory
     */
    function _updateDynamic() internal {
        uint256 fromStart = block.timestamp - startTime;

        if (fromStart > 7 days && !passedBasePeriod) {
            IPriorityPoolFactory(priorityPoolFactory).addDynamicCounter();
            passedBasePeriod = true;
        }
    }

    /**
     * @notice Update rewards
     */

    function _updateRewards() internal {
        (
            uint256 lastRewardYear,
            uint256 lastRewardMonth,
            uint256 lastRewardDay
        ) = DateTimeLibrary.timestampToDate(lastRewardTimestamp);

        (
            uint256 currentYear,
            uint256 currentMonth,
            uint256 currentDay
        ) = DateTimeLibrary.timestampToDate(block.timestamp);

        uint256 monthPassed = currentMonth - lastRewardMonth;

        uint256 totalReward;
        uint256 tempYear = lastRewardYear;
        uint256 tempMonth = lastRewardMonth;

        if (monthPassed == 0) {
            totalReward +=
                (block.timestamp - lastRewardTimestamp) *
                rewardSpeed[currentYear][currentMonth];
        } else {
            for (uint256 i; i < monthPassed + 1; ) {
                // First month reward
                if (i == 0) {
                    // End timestamp of the first month
                    uint256 endTimestamp = DateTimeLibrary
                        .timestampFromDateTime(
                            lastRewardYear,
                            lastRewardMonth,
                            lastRewardDay,
                            23,
                            59,
                            59
                        );
                    totalReward +=
                        (endTimestamp - lastRewardTimestamp) *
                        rewardSpeed[lastRewardYear][lastRewardMonth];
                }
                // Last month reward
                else if (i == monthPassed) {
                    uint256 startTimestamp = DateTimeLibrary
                        .timestampFromDateTime(tempYear, tempMonth, 1, 0, 0, 0);

                    totalReward +=
                        (block.timestamp - startTimestamp) *
                        rewardSpeed[tempYear][tempMonth];
                }
                // Middle month reward
                else {
                    uint256 daysInMonth = DateTimeLibrary._getDaysInMonth(
                        tempYear,
                        tempMonth
                    );

                    totalReward +=
                        (DateTimeLibrary.SECONDS_PER_DAY * daysInMonth) *
                        rewardSpeed[lastRewardYear][lastRewardMonth];
                }

                unchecked {
                    if (++tempMonth == 12) {
                        ++tempYear;
                        tempMonth = 1;
                    }
                }
            }
        }

        // Distribute reward to Priority Pool
        IPremiumRewardPool(premiumRewardPool).distributeToken(
            insuredToken,
            totalReward
        );
    }

    /**
     * @notice Set liquidation status
     */
    function _setLiquidationStatus(bool _liquidated) internal {
        liquidated = _liquidated;
    }

    /**
     * @notice Check the cover length is ok
     */
    function _withinLength(uint256 _length) internal view returns (bool) {
        return _length >= minLength && _length <= maxLength;
    }

    /**
     * @notice Get the expiry date based on cover duration
     *
     * @param _now           Current timestamp
     * @param _coverDuration Months to cover: 1-3
     */
    function getExpiryDateInternal(uint256 _now, uint256 _coverDuration)
        public
        pure
        returns (uint256)
    {
        // Get the day of the month
        (, , uint256 day) = DateTimeLibrary.timestampToDate(_now);

        // Cover duration of 1 month means current month
        // unless today is the 25th calendar day or later
        uint256 monthToAdd = _coverDuration - 1;

        if (day >= 25) {
            // Add one month
            monthToAdd += 1;
        }

        return _getNextMonthEndDate(_now, monthToAdd);
    }

    function _getNextMonthEndDate(uint256 date, uint256 monthsToAdd)
        private
        pure
        returns (uint256)
    {
        uint256 futureDate = DateTimeLibrary.addMonths(date, monthsToAdd);
        return _getMonthEndTimestamp(futureDate);
    }

    function _getMonthEndTimestamp(uint256 _date)
        private
        pure
        returns (uint256)
    {
        // Get the year and month from the date
        (uint256 year, uint256 month, ) = DateTimeLibrary.timestampToDate(
            _date
        );

        // Count the total number of days of that month and year
        uint256 daysInMonth = DateTimeLibrary._getDaysInMonth(year, month);

        // Get the month end timestamp
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

    function _toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
