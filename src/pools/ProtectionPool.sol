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

import "./interfaces/ProtectionPoolDependencies.sol";
import "./interfaces/IPremiumRewardPool.sol";

import "../util/OwnableWithoutContext.sol";

import "../interfaces/ExternalTokenDependencies.sol";

import "../libraries/DateTime.sol";

import "forge-std/console.sol";

/**
 * @title Protection Pool
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the protection pool contract for Degis Protocol Protection
 *
 *         Users can provide liquidity to protection pool and get PRO_LP token.
 *         If the insurance pool is unable to fulfil the insurance, the reinsurance pool
 *         will be able to provide the insurance to the user.
 */
contract ProtectionPool is
    ERC20,
    ProtectionPoolDependencies,
    ExternalTokenDependencies,
    OwnableWithoutContext
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant DISTRIBUTION_PERIOD = 30 days;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    bool public paused;

    uint256 public startTime;

    // Variables about distributing reward
    // Accumulated reward per share (lp token)
    uint256 public accumulatedRewardPerShare;

    // Last reward update timestamp
    uint256 public lastRewardTimestamp;

    // Emission end tiemstamp
    uint256 public emissionEndTime;

    // Current emission rate
    uint256 public emissionRate;

    // Total covered amount of all insurance pools
    uint256 public totalCovered;

    // PRO_LP token price
    uint256 public price;

    // Year => Month => Speed
    mapping(uint256 => mapping(uint256 => uint256)) rewardSpeed;

    address public premiumRewardPool;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MoveLiquidity(uint256 poolId, uint256 amount);
    event LiquidityProvision(uint256 amount, uint256 lpAmount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event EmissionRateUpdated(
        uint256 newEmissionRate,
        uint256 newEmissionEndTime
    );
    event AccRewardsPerShareUpdated(uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield
    )
        ERC20("ProtectionPool", "PRO_LP")
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        // Register time that pool was deployed
        startTime = block.timestamp;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Only allowed to be called from a pool
    modifier poolOnly() {
        require(
            IInsurancePoolFactory(insurancePoolFactory).poolRegistered(
                msg.sender
            ),
            "Pool not found"
        );
        _;
    }

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
     * @notice Get total active cover amount of all pools
     *
     * @return covered Covered amount
     */
    function getTotalCovered() external view returns (uint256 covered) {
        uint256 poolAmount = IInsurancePoolFactory(insurancePoolFactory)
            .poolCounter();

        for (uint256 i; i < poolAmount; ) {
            (, address poolAddress, , , ) = IInsurancePoolFactory(
                insurancePoolFactory
            ).pools(i);

            if (
                IInsurancePoolFactory(insurancePoolFactory).alreadyDynamic(
                    poolAddress
                )
            ) {
                covered += IInsurancePool(poolAddress).activeCovered();
            } else continue;
        }
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

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
     * @notice mints liquidity tokens. Only callable through policyCenter
     *
     * @param _amount Liquidity amount (shield)
     */
    function providedLiquidity(uint256 _amount, address _provider)
        external
        onlyPolicyCenter
    {
        require(_amount > 0, "Zero amount");

        _updateReward();
        _updatePrice();

        // Mint PRO_LP tokens to the user
        uint256 amountToMint = _amount / price;
        _mint(_provider, amountToMint);

        emit LiquidityProvision(_amount, amountToMint, _provider);
    }

    /**
     * @notice Update when new cover is bought
     *
     * @param _premium Premium of the cover to be distributed to Protection Pool
     * @param _length  Length in month
     */
    function updateWhenBuy(uint256 _premium, uint256 _length)
        external
        onlyPolicyCenter
    {
        _updateReward();
        _updatePrice();

        _updateRewardSpeed(_premium, _length);
    }

    function _updateReward() internal {
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
                if (i == monthPassed) {
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

        // Distribute reward to Protection Pool
        IPremiumRewardPool(premiumRewardPool).distributeShield(totalReward);
    }

    /**
     * @notice Update the price of PRO_LP token
     */
    function _updatePrice() internal {
        price = IERC20(shield).balanceOf(address(this)) / totalSupply();
    }

    /**
    @notice burns liquidity tokens. Only callable through policyCenter
     *
    @param _amount      token being insured
    @param _provider    liquidity provider adress
    */
    function removedLiquidity(uint256 _amount, address _provider)
        external
        onlyPolicyCenter
    {
        require(_amount <= totalSupply(), "amount exceeds totalSupply");
        require(_amount > 0, "amount should be greater than 0");

        require(!paused, "cannot remove liquidity while paused");

        require(
            totalSupply() - _amount >=
                IInsurancePoolFactory(insurancePoolFactory).totalMaxCapacity(),
            "undermines reinsurance capability"
        );
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
    }

    /**
     * @notice Sets paused state of the reinsurance pool
     *
     * @param _paused true if paused, false if not.
     */
    function pauseProtectionPool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == incidentReport),
            "Only owner or Incident Report can call this function"
        );
        paused = _paused;
    }

    /**
     * @notice Update reward speed
     *
     * @param _premium New premium received
     * @param _length  Cover length in months
     */
    function _updateRewardSpeed(uint256 _premium, uint256 _length) internal {
        uint256 newSpeed = _premium / _length;

        (
            uint256 currentYear,
            uint256 currentMonth,
            uint256 currentDay
        ) = DateTimeLibrary.timestampToDate(block.timestamp);

        // If later than day 25, one more month
        if (currentDay >= 25) ++_length;

        uint256 tempYear = currentYear;
        uint256 tempMonth = currentMonth;

        for (uint256 i; i < _length; ) {
            rewardSpeed[tempYear][tempMonth] += newSpeed;

            unchecked {
                if (++tempMonth == 12) {
                    ++tempYear;
                    tempMonth = 1;
                }
            }
        }
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //
}
