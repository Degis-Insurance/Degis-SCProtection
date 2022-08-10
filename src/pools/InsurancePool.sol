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

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/InsurancePoolDependencies.sol";

import "../util/OwnableWithoutContext.sol";

import "../libraries/DateTime.sol";

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
contract InsurancePool is
    ERC20,
    InsurancePoolDependencies,
    OwnableWithoutContext,
    Pausable
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Time to distribute premium payments to liquidity providers
    uint256 public constant DISTRIBUTION_PERIOD = 30;

    // Time users have to claim payout when pool is liquidated
    uint256 public constant CLAIM_PERIOD = 90;

    uint256 public constant MIN_COVER_AMOUNT = 1 ether;

    // Max time length in days of granted protection
    uint256 public immutable maxLength;

    // Min time length in days
    uint256 public immutable minLength;

    // Base premium ratio (max 10000) (260 means 2.6% annually)
    uint256 public immutable basePremiumRatio;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Admin address, set to be the owner of factory
    address public admin;

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

    // Reward speed for the next 3 months
    uint256[] public rewardSpeed;

    // Total active covered amount
    uint256 public totalCovered;

    //

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event Liquidation(uint256 amount, uint256 endDate);
    event EmissionRateUpdated(
        uint256 newEmissionRate,
        uint256 newEmissionEndTime
    );
    event AccRewardsPerShareUpdated(uint256 amount);
    event LiquidationEnded(uint256 timestamp);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _name,
        string memory _symbol,
        uint256 _baseRatio,
        address _admin
    ) ERC20(_name, _symbol) OwnableWithoutContext(_admin) {
        // token address insured by pool
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;

        basePremiumRatio = _baseRatio;

        // TODO: change length
        maxLength = 3;
        minLength = 1;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Only executor contract
    modifier onlyExecutor() {
        require(msg.sender == executor, "Only executor can call this function");
        _;
    }

    // Only policy center contract
    modifier onlyPolicyCenter() {
        require(
            msg.sender == policyCenter,
            "Only policy center can call this function"
        );
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
        returns (uint256)
    {
        require(_amount >= MIN_COVER_AMOUNT, "Under minimum cover amount");
        require(_withinLength(_length), "Wrong cover length");

        uint256 dynamicRatio = dynamicPremiumRatio();

        uint256 endTimestamp = getExpiryDateInternal(block.timestamp, _length);
        uint256 length = endTimestamp - block.timestamp;

        return (dynamicRatio * _amount * length) / (SECONDS_PER_YEAR * 10000);
    }

    function activeCovered() public view returns (uint256 covered) {}

    /**
     * @notice Get the dynamic premium ratio (annually)
     *         Depends on the covers sold and liquidity amount
     */
    function dynamicPremiumRatio() public view returns (uint256 ratio) {
        // Covered ratio = Covered amount of this pool / Total covered amount
        uint256 coveredRatio = (totalCovered * SCALE) /
            IProtectionPool(protectionPool).totalCovered();

        // LP Token ratio = LP token in this pool / Total lp token
        uint256 tokenRatio = (totalSupply() * SCALE) /
            IProtectionPool(protectionPool).totalSupply();

        // Dynamic premium ratio
        ratio = (basePremiumRatio * coveredRatio) / tokenRatio;
    }


    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Pause this pool
     *
     * @param _paused True to pause, false to unpause
     */
    function pauseInsurancePool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == incidentReport),
            "Only owner or Incident Report can call this function"
        );
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

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

    function setInsurancePoolFactory(address _insurancePoolFactory)
        external
        onlyOwner
    {
        _setInsurancePoolFactory(_insurancePoolFactory);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Provide liquidity to liquidity pool
     *         Only callable through policyCenter
     *         Can not provide new liquidity when liquidated
     *
     * @param _amount   Amount of liquidity to provide
     * @param _provider Liquidity provider adress
     */
    function provideLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        onlyPolicyCenter
    {
        require(!liquidated, "Liquidated");
        require(_amount > 0, "Amount should be greater than 0");
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
    function removeLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        onlyPolicyCenter
    {
        // require(_amount + totalSupply() <= maxCapacity, "Exceed max capacity");

        require(
            !liquidated,
            "Pool has been liquidated, cannot remove liquidity"
        );

        require(_amount > 0, "amount should be greater than 0");
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
    }

    /**
     * @notice Called when liqudity is provided, removed or coverage is bought.
     *         updates all state variables to reflect current reward emission.
     */
    function updateRewards() public onlyPolicyCenter {
        _updateRewards();
    }

    /**
     * @notice Update emission rate based on new premium comission to liquidity providers
     *
     * @param _premium premium given to liquidity providers
     */
    function updateEmissionRate(uint256 _premium) public onlyPolicyCenter {
        _updateEmissionRate(_premium);
    }

    /**
     * @notice Sets this insurance pool status to liquidated
     *         Only callable by executor
     *         Only after the report has passed the voting
     */
    function liquidatePool() external onlyExecutor {
        // changes the status of the insurance pool to liquidated and allows payout claims
        _setLiquidationStatus(true);

        // when liquidated, totalSupply does not change. liquidity providers keep LP tokens.
        // LP tokens represent their share of remaining liquidity after payout is done.
        uint256 amount = totalSupply();

        // Set end liquidation date
        // Users will have CLAIM_PERIOD days to claim payout.
        endLiquidationDate = block.timestamp + CLAIM_PERIOD * 1 days;

        // emit event to notify users that pool has been liquidated.
        emit Liquidation(amount, endLiquidationDate);
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

    function increaseMaxCapacity(uint256 _maxCapacity) external onlyOwner {
        maxCapacity = _maxCapacity;
        IInsurancePoolFactory(insurancePoolFactory).updateMaxCapacity(
            maxCapacity
        );
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Updates emission rate based on new incoming premium
     *
     * @param _premium Incoming new premium
     */
    function _updateEmissionRate(uint256 _premium) internal {
        // Update current reward taking into account new emission rate
        _updateRewards();

        if (_premium > 0) {
            // Get time to complete current pool of tokens emission to liquidity providers
            uint256 timeToFinishEmission = emissionEndTime > block.timestamp
                ? emissionEndTime - block.timestamp
                : 0;

            // Calculate new emission rate by adding new premium and redistributing previous emission
            // Throughout the time it takes to complete emission.
            if (timeToFinishEmission > 0) {
                emissionRate =
                    ((emissionRate * timeToFinishEmission) + _premium) /
                    DISTRIBUTION_PERIOD;
                // Update emission rate
            } else {
                // Update emission rate
                emissionRate = _premium / DISTRIBUTION_PERIOD;
            }

            // update emission rate and emission ends
            emissionEndTime = block.timestamp + (DISTRIBUTION_PERIOD * 1 days);

            emit EmissionRateUpdated(emissionRate, emissionEndTime);
        }
    }

    /**
     * @notice Update rewards
     */
    function _updateRewards() internal {
        if (totalSupply() == 0 || emissionEndTime == 0) {
            // if totalSupply is 0, no rewards can be paid
            // update last time rewards were claimed
            lastRewardTimestamp = block.timestamp;
        } else {
            // if no coverages have been bought in over 30 days,
            // discount time passed since the time that emission ends.
            uint256 claimTimestamp = emissionEndTime < block.timestamp
                ? emissionEndTime
                : block.timestamp;

            // Calculate difference between claim time and last time rewards were claimed
            uint256 timeSinceLastReward = claimTimestamp - lastRewardTimestamp;

            // Calculate new reward
            uint256 rewards = (timeSinceLastReward * emissionRate) / 1 days;

            // Update accumulated rewards given to each pool share
            // accumulated
            accumulatedRewardPerShare += rewards / totalSupply();
            lastRewardTimestamp = block.timestamp;

            // emit event to notify users that rewards have been updated
            emit AccRewardsPerShareUpdated(accumulatedRewardPerShare);
        }
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
}
