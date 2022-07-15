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

    struct Liquidity {
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
    // up to 25% discount if protection is bought for an entire year
    uint256 constant DISCOUNT_DIVISOR = 1460;

    mapping(address => Coverage) public coverages;
    address public insuredToken;
    address public manager;
    bool public paused;
    bool public liquidated;
    uint256 public maxCapacity;
    uint256 public maxLength;
    //totalLiquidity is expressed with totalSupply()
    
    //provider address => Liquidity provision
    mapping(address => Liquidity) public liquidities;

    uint256 public startTime;
    uint256 public policyPricePerShield;
    uint256 public totalInsured;
    // total reward might

    uint256 public totalReward;
    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public emissionRate;

    address public deg;
    address public veDeg;
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
        string memory _symbol,
        uint256 _policyPricePerShield,
        address _manager
    ) ERC20(_name, _symbol) {
        
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;
        policyPricePerShield = _policyPricePerShield;
        manager = _manager;
        maxLength = 365;
    }

    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor) || (msg.sender == manager),
            "Only owner or executor can call this function"
        );
        _;
    }

    function setMaxLength(uint256 _maxLength) external onlyOwnerOrExecutor {
        maxLength = _maxLength;
    }

    function setDeg(address _deg) external onlyOwnerOrExecutor {
        deg = _deg;
    }

    function setVeDeg(address _veDeg) external onlyOwnerOrExecutor {
        veDeg = _veDeg;
    }

    function setShield(address _shield) external onlyOwnerOrExecutor {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external onlyOwnerOrExecutor {
        policyCenter = _policyCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwnerOrExecutor {
        reinsurancePool = _reinsurancePool;
    }

    function setProposalCenter(address _proposalCenter) external onlyOwnerOrExecutor {
        proposalCenter = _proposalCenter;
    }

    function setExecutor(address _executor) external onlyOwnerOrExecutor {
        executor = _executor;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory) external onlyOwnerOrExecutor {
        insurancePoolFactory = _insurancePoolFactory;
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
        return (name(), insuredToken, maxCapacity, totalSupply());
    }

    function coveragePrice(uint256 _amount, uint256 _length)
        public
        view
        returns (uint256)
    {
        require(_amount > 0, "amount cannot be zero");
        require(_length > 0, "length cannot be zero");
        require(_length <= maxLength, "length cannot be greater than MAX_LENGTH");
        return (policyPricePerShield *_amount * _length / 1 days * (DISCOUNT_DIVISOR + 1 - _length)) /
            DISCOUNT_DIVISOR;
    }

    function getCoverage(address _covered) public view returns (uint256, uint256, uint256) {
        return (coverages[_covered].amount, coverages[_covered].buyDate, coverages[_covered].length);
    }

    function setMaxCapacity(uint256 _maxCapacity) external onlyOwnerOrExecutor {
        maxCapacity = _maxCapacity;
    }

    function provideLiquidity(uint256 _amount, address _provider) external {
        require(
            _amount <= maxCapacity - totalSupply(),
            "amount exceeds maxCapacity"
        );
        require(!liquidated, "cannot provide new liquidity");
        require(_amount > 0, "amount should be greater than 0");
        require(msg.sender == policyCenter, "you can only provide liquidity through policy center");
        uint256 reward = calculateReward(_provider);
        liquidities[msg.sender].userDebt += accumulatedRewardPerShare * (liquidities[msg.sender].amount + _amount);
        liquidities[msg.sender].lastClaim = block.timestamp;
        IERC20(shield).transfer(msg.sender, reward);
        _mint(_provider, _amount);   
    }

    function removeLiquidity(uint256 _amount, address _provider) external {
        require(
            !liquidated,
            "Pool has been liquidated, cannot remove liquidity"
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
        require(msg.sender == policyCenter, "you can only provide liquidity through policy center");

        require(!paused, "cannot remove liquidity while paused");
        uint256 reward = calculateReward(_provider);
        liquidities[msg.sender].userDebt += accumulatedRewardPerShare * (liquidities[msg.sender].amount - liquidities[msg.sender].userDebt);
        liquidities[msg.sender].lastClaim = block.timestamp;
        _burn(_provider, _amount);
        ERC20(shield).transfer(_provider, _amount + reward);        
    }

    function addPremium(uint256 _amount) external {
        require(
            msg.sender == policyCenter,
            "Only policyCenter can add premium"
        );
        require(_amount > 0, "amount should be greater than 0");
        totalReward += _amount;
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
            (totalSupply() == 0 ? 1 : totalSupply());
        emissionRate =
            (totalReward - totalDistributedReward + _paid) / DISTRIBUTION_PERIOD;
    }

    function claimReward(address _provider) public {
        require(msg.sender == policyCenter, "Not sent from policy center");
        require(!liquidated, "Pool has been liquidated, cannot claim stake");
        uint256 stake = liquidities[_provider].amount;
        require(stake > 0, "No stake to claim");

        uint256 reward = calculateReward(_provider);
        liquidities[_provider].userDebt += reward;
        IERC20(shield).transfer(_provider, reward);
    }

    function calculateReward(address _provider) public view returns(uint256) {
        return accumulatedRewardPerShare * liquidities[_provider].amount - liquidities[_provider].userDebt;
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
        if (totalSupply() >= amount) {
            IERC20(shield).transfer(_insured, amount);
        } else {
            IERC20(shield).transfer(_insured, amount);
            _requestReinsurance(amount - totalSupply(), msg.sender);
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
            _amount - totalSupply(),
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
