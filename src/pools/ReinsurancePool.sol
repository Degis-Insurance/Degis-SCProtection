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
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";

contract ReinsurancePool is
    ReinsurancePoolErrors,
    ERC20("ReinsurancePoolLP", "RLP"),
    Ownable
{
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    address public DEG;
    address public veDEG;
    address public shield;
    address public insurancePoolFactory;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;
    address public premiumVault;
    address public insurancePool;

    bool public insurancePoolLiquidated;
    bool public paused;

    struct PoolInfo {
        address protocolAddress;
        uint256 proportion;
    }
    mapping(address => PoolInfo) public pools;

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

    function setShield(address _shield) external onlyOwner {
        shield = _shield;
    }

    function endLiquidationPeriod() external onlyOwner {
        insurancePoolLiquidated = false;
    }



    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function provideLiquidity(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();

        IERC20(shield).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function removeLiquidity(uint256 _amount) external {
        require(!insurancePoolLiquidated, "insurance pool liquidated cannot remove liquidity");
        require(!paused, "pool is paused");
        if (_amount == 0) revert ZeroAmount();

        IERC20(shield).transfer(msg.sender, _amount);
        _burn(msg.sender, _amount);
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
