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
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ReinsurancePoolErrors.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IComittee.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IExecutor.sol";

contract InsurancePool is ERC20, Ownable {
    struct Stake {
        uint256 amount;
        uint256 userDebt;
        uint256 lastClaim;
    }

    struct Coverage {
        uint256 amount;
        uint256 buyDate;
        uint256 length;
    }

    uint256 constant DISTRIBUTION_PERIOD = 30 days;

    mapping(address => Coverage) public coverages;
    address public insuredToken;
    bool public paused;
    bool public liquidated;
    uint256 public maxCapacity;
    uint256 public liquidity;

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;

    uint256 public premiumToSplit;
    uint256 public startTime;
    uint256 public policyPricePerShield;
    uint256 public totalInsured;
    // total reward might

    uint256 public totalReward;
    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public emissionRate;

    address public DEG;
    address public veDEG;
    address public shield;
    address public insurancePoolFactory;
    address public policyCenter;
    address public proposalCenter;
    address public executor;
    address public reinsurancePool;
    address public premiumVault;

    event Payout(uint256 amount, address sender);
    event Claim(uint256 amount, address sender);
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event Liquidation(uint256 amount);

    constructor(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;
    }

    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor),
            "Only owner or executor can call this function"
        );
        _;
    }

    function isLiquidated() public view returns (bool) {
        return liquidated;
    }

    function poolInfo()
        public
        view
        returns (
            string memory,
            address,
            uint256,
            uint256
        )
    {
        return (name(), insuredToken, maxCapacity, liquidity);
    }

    function policyPrice(uint256 _amount, uint256 _length)
        public
        view
        returns (uint256)
    {
        // TODO: calculate policy cost properly
        return _amount * policyPricePerShield * _length;
    }

    function setMaxCapacity(uint256 _maxCapacity) external onlyOwnerOrExecutor {
        maxCapacity = _maxCapacity;
    }

    function provideLiquidity(uint256 _amount, address _provider) external {
        require(
            _amount < maxCapacity - totalSupply(),
            "amount exceeds maxCapacity"
        );
        require(!liquidated, "cannot provide new liquidity");
        require(_amount > 0, "amount should be greater than 0");
        require(
            (_provider == tx.origin) || (_provider == msg.sender),
            "provider should be the caller"
        );
        _mint(msg.sender, _amount);
        liquidity += _amount;
    }

    function removeLiquidity(uint256 _amount, address _provider) external {
        require(
            !liquidated,
            "Pool has been liquidated, cannot remove liquidity"
        );
        require(_amount < totalSupply(), "amount exceeds totalSupply");
        require(
            block.timestamp + 604800 > stakes[msg.sender].lastClaim,
            "cannot remove liquidity within 7 days of last claim"
        );
        require(
            stakes[msg.sender].amount <= _amount,
            "amount exceeds staked amount"
        );

        require(!paused, "cannot remove liquidity while paused");
        _burn(_provider, _amount);
        liquidity -= _amount;
        totalReward =
            accumulatedRewardPerShare *
            _amount -
            stakes[msg.sender].userDebt;
        ERC20(shield).transfer(_provider, _amount);
    }

    function addPremium(uint256 _amount) external {
        require(
            msg.sender == policyCenter,
            "Only policyCenter can add premium"
        );
        require(_amount > 0, "amount should be greater than 0");
        premiumToSplit += _amount;
    }

    function buyCoverage(
        uint256 _paid,
        uint256 _amount,
        uint256 _length,
        address _insured
    ) external {
        require(
            msg.sender == policyCenter,
            "Only policyCenter can buy coverage"
        );
        require(
            _paid > 0,
            "InsurancePool: buyCoverage: paid should be greater than 0"
        );

        coverages[_insured] = Coverage(_amount, block.timestamp, _length);
        totalReward += _paid;
        totalDistributedReward += emissionRate * (block.timestamp - startTime);
        accumulatedRewardPerShare +=
            (emissionRate * (block.timestamp - startTime)) /
            totalSupply();
        emissionRate =
            (totalReward - totalDistributedReward + _paid) /
            DISTRIBUTION_PERIOD;
    }

    function claimDebt(address _provider) public {
        require(msg.sender == _provider, "Not provider");
        require(!liquidated, "Pool has been liquidated, cannot claim stake");
        uint256 stake = stakes[_provider].amount;
        require(stake > 0, "No stake to claim");
        uint256 debt = stakes[_provider].userDebt;
        require(debt > 0, "No debt to claim");
        stakes[_provider].userDebt = 0;
        IERC20(shield).transfer(_provider, debt);
    }

    function claimPayout(address _insured) external {
        require(liquidated, "payout: pool is not claimable");
        require(
            (msg.sender == policyCenter) || (msg.sender == _insured),
            "sender is not policy center or insured"
        );
        require(coverages[_insured].amount > 0, "no coverage to claim");
        uint256 amount = (coverages[_insured].amount / totalInsured) *
            totalReward;
        coverages[_insured].amount = 0;
        totalInsured -= coverages[_insured].amount;
        if (liquidity >= amount) {
            IERC20(shield).transfer(_insured, amount);
        } else {
            IERC20(shield).transfer(_insured, amount);
            _requestReinsurance(amount - liquidity, msg.sender);
        }
        emit Payout(amount, msg.sender);
    }

    function liquidatePool() external onlyOwnerOrExecutor {
        _setLiquidationStatus(true);
        uint256 amount = totalSupply();

        emit Liquidation(amount);
    }

    function _setLiquidationStatus(bool _liquidated) internal {
        liquidated = _liquidated;
    }

    function _requestReinsurance(uint256 _amount, address _address) internal {
        IReinsurancePool(reinsurancePool).reinsurePool(
            _amount - liquidity,
            _address
        );
    }

    function setPausedInsurancePool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == proposalCenter),
            "Only owner or proposalCenter can call this function"
        );
        paused = _paused;
    }
    //totalSupply < maxCapacity

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //
}
