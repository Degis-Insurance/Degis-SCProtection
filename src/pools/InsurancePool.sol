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

import "forge-std/console.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Smart Contract Protection
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

    // Premium ratio (max 10000) (260 means 2.6% annually)
    uint256 public immutable premiumRatio;

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
        uint256 _premiumRatio,
        address _admin
    ) ERC20(_name, _symbol) OwnableWithoutContext(_admin) {
        // token address insured by pool
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;

        premiumRatio = _premiumRatio;

        maxLength = 90;
        minLength = 7;
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
     * @notice returns cost to buy coverage for a given period of time and amount of tokens
     *
     * @param _amount Amount being covered
     * @param _length Coverage length in days
     */
    function coveragePrice(uint256 _amount, uint256 _length)
        external
        view
        returns (uint256)
    {
        require(_amount >= MIN_COVER_AMOUNT, "Under minimum cover amount");
        require(_withinLength(_length), "Wrong cover length");

        // price in bps per year * amount of tokens to receive when pool is liquidated
        // * lenght of coverage in days / year and 10000 to get bps to percentage
        return (premiumRatio * _amount * _length) / 3650000;
    }

    /**
     * @notice Calculate your reward
     *
     * @param _amount   Amount in provided liquidity
     * @param _userDebt Amount of debt the user
     */
    function calculateReward(uint256 _amount, uint256 _userDebt)
        external
        view
        returns (uint256)
    {
        if (totalSupply() == 0) {
            return 0;
        }
        uint256 timePassed = block.timestamp - lastRewardTimestamp;
        uint256 rewards = timePassed * emissionRate;

        uint256 acc = accumulatedRewardPerShare + rewards / totalSupply();
        uint256 reward = (_amount * acc) - _userDebt;
        return reward;
    }

    /**
     * @notice returns pool information
     */
    function poolInfo()
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            paused(),
            accumulatedRewardPerShare,
            lastRewardTimestamp,
            emissionEndTime,
            emissionRate,
            maxCapacity
        );
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

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Provide liquidity from liquidity pool. Only callable through policyCenter
     *
     * @param _amount   Amount of liquidity to provide
     * @param _provider Liquidity provider adress
     */
    function provideLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        onlyPolicyCenter
    {
        require(!liquidated, "cannot provide new liquidity");
        require(_amount > 0, "amount should be greater than 0");

        _mint(_provider, _amount);
        emit LiquidityProvision(_amount, _provider);
    }

    /**
     * @notice Remove liquidity from insurance pool. Only callable through policyCenter
     *
     * @param _amount   Amount of liquidity to remove
     * @param _provider Provider address
     */
    function removeLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        onlyPolicyCenter
    {
        require(
            !liquidated,
            "Pool has been liquidated, cannot remove liquidity"
        );

        require(_amount > 0, "amount should be greater than 0");
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
    }

    /**
    @notice Called when liqudity is provided, removed or coverage is bought.
    updates all state variables to reflect current reward emission.
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
     * @notice Updates emission rate based on new incoming premium
     *
     * @param _premium Incoming new premium
     */
    function _updateEmissionRate(uint256 _premium) internal {
        // Update current reward taking into account new emission rate
        _updateRewards();

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
}
