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

    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public lastRewardTimestamp;
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
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);

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

    function calculateReward(uint256 _amount, uint256 _userDebt) public view returns(uint256) {
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;
        uint256 acc = accumulatedRewardPerShare + (rewards / totalSupply());
        uint256 reward = (_amount * acc) - _userDebt;
        return reward;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

   /**
    @dev mints liquidity tokens. Only callable through policyCenter
    @param _amount token being insured
    @param _provider liquidity provider adress
    */
    function provideLiquidity(uint256 _amount, address _provider) external {        
        require(_amount > 0, "amount should be greater than 0");
        require(msg.sender == policyCenter, "cannot provide liquidity directly to insurance pool");
        _mint(_provider, _amount);
        emit LiquidityProvision(_amount, _provider);  
    }

     /**
    @dev burns liquidity tokens. Only callable through policyCenter
    @param _amount token being insured
    @param _provider liquidity provider adress
    */
    function removeLiquidity(uint256 _amount, address _provider) external {
        require(_amount <= totalSupply(), "amount exceeds totalSupply");
        require(block.timestamp >= liquidities[msg.sender].lastClaim + 604800,
                "cannot remove liquidity within 7 days of last claim");
        require(_amount > 0, "amount should be greater than 0");
        require(msg.sender == policyCenter, "liquidity can only be provide through policy center");
        require(!paused, "cannot remove liquidity while paused");
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider); 
    }

    /**
    @dev provides liquidity to pools in need of it. Only callable by Pools
    @param _amount token being insured
    @param _address address of covered wallet
    */   
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

    /**
     * @notice Sets paused state of the reinsurance pool
     * @param _paused true if paused, false if not.
     */
    function setPausedReinsurancePool(bool _paused) external {
        require((msg.sender == owner()) || (msg.sender == proposalCenter), "Only owner or proposalCenter can call this function");
        paused = _paused;
    }
}
