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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";
import "../util/Setters.sol";

contract ReinsurancePool is
    ReinsurancePoolErrors,
    ERC20("ReinsurancePoolLP", "RLP"),
    Ownable, Setters
{

    struct Liquidity {
        uint256 amount;
        uint256 userDebt;
        uint256 lastClaim;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    bool public insurancePoolLiquidated;
    bool public paused;

    uint256 public totalReward;
    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public emissionRate;

    struct PoolInfo {
        address protocolAddress;
        uint256 proportion;
    }
    mapping(address => PoolInfo) public pools;
    mapping(address => Liquidity) public liquidities;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MoveLiquidity(uint256 poolId, uint256 amount);

    constructor(address _shield) {
        shield = _shield;
    }

    modifier poolOnly() {
        require(
            IPolicyCenter(policyCenter).isPoolAddress(msg.sender),
            "Pool not found"
        );
        _;
    }


    function endLiquidationPeriod() external onlyOwner {
        insurancePoolLiquidated = false;
    }

    function calculateReward(address _provider) public view returns(uint256) {
        return accumulatedRewardPerShare * liquidities[_provider].amount - liquidities[_provider].userDebt;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

   function provideLiquidity(uint256 _amount, address _provider) external {
        require(!insurancePoolLiquidated, "cannot provide new liquidity");
        require(_amount > 0, "amount should be greater than 0");
        require(msg.sender == policyCenter, "you can only provide liquidity through policy center");
        uint256 reward = calculateReward(_provider);
        if (reward > 0) {
            liquidities[msg.sender].userDebt += accumulatedRewardPerShare * (liquidities[msg.sender].amount + _amount);
            liquidities[msg.sender].lastClaim = block.timestamp;
            // reward liquidity provider
            IERC20(shield).transfer(_provider, reward);
        }
        _mint(_provider, _amount);   
    }

    function removeLiquidity(uint256 _amount, address _provider) external {
        require(
            !insurancePoolLiquidated,
            "Pool liquidated, cannot remove liquidity"
        );
        require(_amount <= totalSupply(), "amount exceeds totalSupply");
        require(
            block.timestamp >= liquidities[msg.sender].lastClaim + 604800,
            "cannot remove liquidity within 7 days of last claim"
        );
        require(
            liquidities[msg.sender].amount <= _amount,
            "amount exceeds staked amount"
        );
        require(msg.sender == policyCenter, "liquidity can only be provide through policy center");

        require(!paused, "cannot remove liquidity while paused");
        uint256 reward = calculateReward(_provider);
        liquidities[msg.sender].userDebt += accumulatedRewardPerShare * (liquidities[msg.sender].amount - liquidities[msg.sender].userDebt);
        liquidities[msg.sender].lastClaim = block.timestamp;
        _burn(_provider, _amount);
        IERC20(shield).transfer(_provider, _amount + reward);        
    }

    function addPremium(uint256 _amount) external {
        require(
            msg.sender == policyCenter,
            "Only policyCenter can add premium"
        );
        require(_amount > 0, "amount should be greater than 0");
        totalReward += _amount;
    }

    function claimReward(address _provider) public {
        require(msg.sender == policyCenter, "Not sent from policy center");
        require(!insurancePoolLiquidated, "Pool has been liquidated, cannot claim stake");
        uint256 stake = liquidities[_provider].amount;
        require(stake > 0, "No stake to claim");

        uint256 reward = calculateReward(_provider);
        liquidities[_provider].userDebt += reward;
        IERC20(shield).transfer(_provider, reward);
    }

    function reinsurePool(uint256 _amount, address _address) external poolOnly {
        if (_amount == 0) revert ZeroAmount();
        IERC20(shield).transferFrom(address(this), _address, _amount);
    }

    /**
     * @notice Move liquidity to another pool to be used for reinsurance.
     * @param _amount Amount of liquidity to move.
     * @param _poolId Id of the pool to move the liquidity to.
     */
    function moveLiquidity(uint256 _poolId, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "Amount must be greater than 0");
        address poolAddress = IPolicyCenter(policyCenter).getInsurancePoolById(_poolId);
        require(poolAddress != address(0), "Pool not found");

        IERC20(shield).transferFrom(address(this), poolAddress, _amount);
        emit MoveLiquidity(_poolId, _amount);
    }

    function setPausedReinsurancePool(bool _paused) external {
        require((msg.sender == owner()) || (msg.sender == proposalCenter), "Only owner or proposalCenter can call this function");
        paused = _paused;
    }
}
