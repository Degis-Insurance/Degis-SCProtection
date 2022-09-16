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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./ProtectionPoolDependencies.sol";
import "./ProtectionPoolEventError.sol";
import "../../interfaces/ExternalTokenDependencies.sol";

import "../../util/OwnableWithoutContext.sol";
import "../../util/PausableWithoutContext.sol";
import "../../util/FlashLoanPool.sol";

import "../../libraries/DateTime.sol";

/**
 * @title Protection Pool
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the protection pool contract for Degis Protocol Protection
 *
 *         Users can provide liquidity to protection pool and get PRO-LP token
 *
 *         If the priority pool is unable to fulfil the cover amount,
 *         Protection Pool will be able to provide the remaining part
 */
contract ProtectionPool is
    ProtectionPoolEventError,
    ERC20,
    FlashLoanPool,
    OwnableWithoutContext,
    PausableWithoutContext,
    ExternalTokenDependencies,
    ProtectionPoolDependencies
{
    using DateTimeLibrary for uint256;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Pool start time
    uint256 public startTime;

    // Last pool reward distribution
    uint256 public lastRewardTimestamp;

    // PRO_LP token price
    uint256 public price;

    // Year => Month => Speed
    mapping(uint256 => mapping(uint256 => uint256)) public rewardSpeed;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield
    )
        ERC20("ProtectionPool", "PRO-LP")
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {
        // Register time that pool was deployed
        startTime = block.timestamp;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyPolicyCenter() {
        if (msg.sender != policyCenter)
            revert ProtectionPool__OnlyPolicyCenter();
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get total active cover amount of all pools
     *         Only calculate those "already dynamic" pools
     *
     * @return activeCovered Covered amount
     */
    function getTotalActiveCovered()
        public
        view
        returns (uint256 activeCovered)
    {
        IPriorityPoolFactory factory = IPriorityPoolFactory(
            priorityPoolFactory
        );

        uint256 poolAmount = factory.poolCounter();

        for (uint256 i; i < poolAmount; ) {
            (, address poolAddress, , , ) = factory.pools(i + 1);

            if (factory.dynamic(poolAddress)) {
                activeCovered += IPriorityPool(poolAddress).activeCovered();
            }

            unchecked {
                ++i;
            }
        }
    }

    function getTotalCovered() public view returns (uint256 totalCovered) {
        IPriorityPoolFactory factory = IPriorityPoolFactory(
            priorityPoolFactory
        );

        uint256 poolAmount = factory.poolCounter();

        for (uint256 i; i < poolAmount; ) {
            (, address poolAddress, , , ) = factory.pools(i + 1);

            totalCovered += IPriorityPool(poolAddress).activeCovered();

            unchecked {
                ++i;
            }
        }
    }

    // @audit change decimal
    function decimals() public pure override returns (uint8) {
        return 6;
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
     * @notice Update index cut when claim happened
     */
    function updateIndexCut() public {
        IPriorityPoolFactory factory = IPriorityPoolFactory(
            priorityPoolFactory
        );

        uint256 poolAmount = factory.poolCounter();

        uint256 currentReserved = IShield(shield).balanceOf(address(this));

        uint256 indexToCut;
        uint256 minRequirement;

        for (uint256 i; i < poolAmount; ) {
            (, address poolAddress, , , ) = factory.pools(i);

            minRequirement = IPriorityPool(poolAddress).minAssetRequirement();

            if (minRequirement > currentReserved) {
                indexToCut = (currentReserved * SCALE) / minRequirement;
                IPriorityPool(poolAddress).setCoverIndex(indexToCut);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Updates and retrieves latest price to provide liquidity to Protection Pool
     */
    function getLatestPrice() external returns (uint256) {
        _updatePrice();
        return price;
    }

    /**
     * @notice Finish providing liquidity
     *         Only callable through policyCenter
     *
     * @param _amount   Liquidity amount (shield)
     * @param _provider Provider address
     */
    function providedLiquidity(uint256 _amount, address _provider)
        external
        onlyPolicyCenter
    {
        _updateReward();
        _updatePrice();

        // Mint PRO_LP tokens to the user
        uint256 amountToMint = (_amount * SCALE) / price;
        _mint(_provider, amountToMint);
        emit LiquidityProvided(_amount, amountToMint, _provider);
    }

    /**
     * @notice Finish removing liquidity
     *         Only callable through policyCenter
     *
     * @param _amount   Liquidity to remove (LP token amount)
     * @param _provider Provider address
     */
    function removedLiquidity(uint256 _amount, address _provider)
        external
        whenNotPaused
        returns (uint256 shieldToTransfer)
    {
        if (
            msg.sender != policyCenter &&
            !IPriorityPoolFactory(priorityPoolFactory).poolRegistered(
                msg.sender
            )
        ) revert ProtectionPool__OnlyPriorityPoolOrPolicyCenter();

        if (_amount > totalSupply())
            revert ProtectionPool__ExceededTotalSupply();

        _updateReward();
        _updatePrice();

        // Burn PRO_LP tokens to the user
        shieldToTransfer = (_amount * price) / SCALE;
        if (
            SimpleIERC20(shield).balanceOf(address(this)) <
            getTotalCovered() + shieldToTransfer
        ) revert ProtectionPool__NotEnoughLiquidity();

        // @audit Change path
        //
        address realPayer = msg.sender == policyCenter ? _provider : msg.sender;
        _burn(realPayer, _amount);
        SimpleIERC20(shield).transfer(_provider, shieldToTransfer);

        emit LiquidityRemoved(_amount, shieldToTransfer, _provider);
    }

    /**
     * @notice Removes liquidity when a claim is made
     *
     * @param _amount Amount of liquidity to remove
     * @param _to     Address to transfer the liquidity to
     */
    function removedLiquidityWhenClaimed(uint256 _amount, address _to)
        external
    {
        if (
            !IPriorityPoolFactory(priorityPoolFactory).poolRegistered(
                msg.sender
            )
        ) revert ProtectionPool__OnlyPriorityPool();

        if (_amount > SimpleIERC20(shield).balanceOf(address(this)))
            revert ProtectionPool__NotEnoughBalance();

        SimpleIERC20(shield).transfer(_to, _amount);

        _updatePrice();

        emit LiquidityRemovedWhenClaimed(msg.sender, _amount);
    }

    /**
     * @notice Update when new cover is bought
     *
     * @param _premium         Premium of the cover to be distributed to Protection Pool
     * @param _length          Length in month
     * @param _timestampLength Length in seconds
     */
    function updateWhenBuy(
        uint256 _premium,
        uint256 _length,
        uint256 _timestampLength
    ) external onlyPolicyCenter {
        _updateReward();
        _updatePrice();

        _updateRewardSpeed(_premium, _length, _timestampLength);
    }

    /**
     * @notice Set paused state of the protection pool
     *
     * @param _paused True for pause, false for unpause
     */
    function pauseProtectionPool(bool _paused) external {
        if (
            (msg.sender != owner()) &&
            (msg.sender != incidentReport) &&
            (msg.sender != priorityPoolFactory)
        ) revert ProtectionPool__NotAllowedToPause();
        _pause(_paused);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Update the price of PRO_LP token
     */
    function _updatePrice() internal {
        if (totalSupply() == 0) {
            price = SCALE;
            return;
        }
        price =
            ((SimpleIERC20(shield).balanceOf(address(this))) * SCALE) /
            totalSupply();

        emit PriceUpdated(price);
    }

    /**
     * @notice Update reward status
     */
    function _updateReward() internal {
        uint256 currentTime = block.timestamp;

        // Last reward year & month & day
        (uint256 lastY, uint256 lastM, uint256 lastD) = lastRewardTimestamp
            .timestampToDate();

        // Current year & month & day
        (uint256 currentY, uint256 currentM, ) = currentTime.timestampToDate();

        uint256 monthPassed = currentM - lastM;

        uint256 totalReward;

        if (monthPassed == 0) {
            if (rewardSpeed[currentY][currentM] > 0) {
                totalReward +=
                    (currentTime - lastRewardTimestamp) *
                    rewardSpeed[currentY][currentM];
            }
        } else {
            for (uint256 i; i < monthPassed + 1; ) {
                // First month reward
                if (i == 0 && rewardSpeed[lastY][lastM] > 0) {
                    // End timestamp of the first month
                    uint256 endTimestamp = DateTimeLibrary
                        .timestampFromDateTime(lastY, lastM, lastD, 23, 59, 59);

                    totalReward +=
                        (endTimestamp - lastRewardTimestamp) *
                        rewardSpeed[lastY][lastM];
                }
                // Last month reward
                else if (i == monthPassed && rewardSpeed[lastY][lastM] > 0) {
                    uint256 startTimestamp = DateTimeLibrary
                        .timestampFromDateTime(lastY, lastM, 1, 0, 0, 0);

                    totalReward +=
                        (currentTime - startTimestamp) *
                        rewardSpeed[lastY][lastM];
                }
                // Middle month reward
                else {
                    uint256 daysInMonth = lastY._getDaysInMonth(lastM);

                    if (rewardSpeed[lastY][lastM] > 0) {
                        totalReward +=
                            (DateTimeLibrary.SECONDS_PER_DAY * daysInMonth) *
                            rewardSpeed[lastY][lastM];
                    }
                }

                unchecked {
                    if (++lastM > 12) {
                        ++lastY;
                        lastM = 1;
                    }

                    ++i;
                }
            }
        }

        emit RewardUpdated(totalReward);
    }

    /**
     * @notice Update reward speed
     *
     * @param _premium         New premium received
     * @param _length          Cover length in months
     * @param _timestampLength Cover length in seconds
     */
    function _updateRewardSpeed(
        uint256 _premium,
        uint256 _length,
        uint256 _timestampLength
    ) internal {
        // How many premiums need to be distributed in each second
        uint256 newSpeed = _premium / _timestampLength;

        (uint256 currentYear, uint256 currentMonth, ) = DateTimeLibrary
            .timestampToDate(block.timestamp);

        for (uint256 i; i < _length; ) {
            rewardSpeed[currentYear][currentMonth] += newSpeed;

            unchecked {
                if (++currentMonth > 12) {
                    ++currentYear;
                    currentMonth = 1;
                }

                ++i;
            }
        }
    }
}
