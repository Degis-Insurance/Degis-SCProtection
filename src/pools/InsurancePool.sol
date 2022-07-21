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
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IComittee.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IExecutor.sol";
import "forge-std/console.sol";
import "../util/Setters.sol";

contract InsurancePool is ERC20, Ownable, Setters {


    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 constant public DISTRIBUTION_PERIOD = 30 days;
    // up to 25% discount if protection is bought for an entire year
    uint256 constant public DISCOUNT_DIVISOR = 1460;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public insuredToken;
    address public administrator;
    bool public paused;
    bool public liquidated;
    uint256 public maxCapacity;
    uint256 public maxLength;
    uint256 public startTime;
    uint256 public policyPricePerShield;
    //totalLiquidity is expressed in totalSupply()
    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public lastRewardTimestamp;
    uint256 public emissionRate;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event Liquidation(uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    
    constructor(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _name,
        string memory _symbol,
        uint256 _policyPricePerShield,
        address _administrator
    ) ERC20(_name, _symbol) {
        
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;
        policyPricePerShield = _policyPricePerShield;
        administrator = _administrator;
        maxLength = 365;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //
    
    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor) || (msg.sender == administrator),
            "Only owner or executor can call this function"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
    @dev returns if the pool has been liquidated for coverage claims
    @return liquidated boolean true if liquidated, false otherwise
     */
    function isLiquidated() public view returns (bool) {
        return liquidated;
    }


    /**
    @dev returns information about the pool
    @return name, insuredToken, maxCapacity, totalSupply and how much is being covered
     */
    function poolInfo()
        public
        view
        returns (
            string memory,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (name(), insuredToken, maxCapacity, totalSupply(), totalDistributedReward);
    }

    /**
    @dev returns cost to buy coverage for a given period of time and amount of tokens
    @param _amount amount being covered
    @param _length coverage length
     */
    function coveragePrice(uint256 _amount, uint256 _length)
        public
        view
        returns (uint256)
    {
        require(_amount > 0, "amount cannot be zero");
        require(_length > 0, "length cannot be zero");
        require(_length <= maxLength, "length cannot be greater than maxLength");
        return (policyPricePerShield *_amount * _length / 1 days * (DISCOUNT_DIVISOR + 1 - _length)) /
            DISCOUNT_DIVISOR;
    }

    function calculateReward(uint256 _amount, uint256 _userDebt, address _provider) public view returns (uint256) {
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;
        uint256 acc = accumulatedRewardPerShare + (rewards / totalSupply());
        uint256 reward = (_amount * acc) - _userDebt;
        return reward;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setMaxLength(uint256 _maxLength) external onlyOwnerOrExecutor {
        maxLength = _maxLength;
    }

    function setDeg(address _deg) external override onlyOwnerOrExecutor {
        deg = _deg;
    }

    function setVeDeg(address _veDeg) external override onlyOwnerOrExecutor {
        veDeg = _veDeg;
    }

    function setShield(address _shield) external override onlyOwnerOrExecutor {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external override onlyOwnerOrExecutor {
        policyCenter = _policyCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external override onlyOwnerOrExecutor {
        reinsurancePool = _reinsurancePool;
    }

    function setProposalCenter(address _proposalCenter) external override onlyOwnerOrExecutor {
        proposalCenter = _proposalCenter;
    }

    function setExecutor(address _executor) external override onlyOwnerOrExecutor {
        executor = _executor;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory) external override onlyOwnerOrExecutor {
        insurancePoolFactory = _insurancePoolFactory;
    }

    function _setLiquidationStatus(bool _liquidated) internal {
        liquidated = _liquidated;
    }

    function setPausedInsurancePool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == proposalCenter),
            "Only owner or proposalCenter can call this function"
        );
        paused = _paused;
    }

    function setMaxCapacity(uint256 _maxCapacity) external onlyOwnerOrExecutor {
        maxCapacity = _maxCapacity;
    }

    function setAdministrator(address _administrator) external onlyOwnerOrExecutor {
        administrator = _administrator;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
    @dev provide liquidity from liquidity pool. Only callable through policyCenter
    @param _amount token being insured
    @param _provider liquidity provider adress
    */
    function provideLiquidity(uint256 _amount, address _provider) external {        
        require(!liquidated, "cannot provide new liquidity");
        require(_amount > 0, "amount should be greater than 0");
        require(msg.sender == policyCenter, "cannot provide liquidity directly to insurance pool");

        _mint(_provider, _amount);
        emit LiquidityProvision(_amount, _provider);  
    }

    /**
    @dev remove liquidity from insurance pool. Only callable through policyCenter
    @param _amount token being insured
    @param _provider liquidity provider adress
    */
    function removeLiquidity(uint256 _amount, address _provider) external {
        require(!liquidated, "Pool has been liquidated, cannot remove liquidity");  
        require(msg.sender == policyCenter, "cannot remove liquidity directly from insurance pool");
        require(!paused, "cannot remove liquidity while paused");
        require(_amount > 0, "amount should be greater than 0");
        _burn(_provider, _amount);      
        emit LiquidityRemoved(_amount, _provider);         
    }

    /**
    @dev called when a coverage is bought on PolicyCenter. Only callable through policyCenter
    @param _paid amount paid to insure amount of tokens
    */
    function registerNewCoverage(
        uint256 _paid
    ) external {
        require(msg.sender == policyCenter, "Only policyCenter can buy coverage");
        require(_paid > 0, "paid should be greater than 0");
        totalDistributedReward += emissionRate * (block.timestamp - startTime);
        accumulatedRewardPerShare +=
            (_paid * (block.timestamp - startTime)) /
            (totalSupply() == 0 ? 1 : totalSupply());
        emissionRate =
            (_paid - totalDistributedReward) / DISTRIBUTION_PERIOD;
    }

    function updateRewards() public {
        require(msg.sender == policyCenter, "Only pollicyCenter can update rewards");
        _updateRewards();
    }

    function liquidatePool() external onlyOwnerOrExecutor {
        _setLiquidationStatus(true);
        uint256 amount = totalSupply();
        emit Liquidation(amount);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    function _updateRewards() internal {
        if (totalSupply() == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;
        accumulatedRewardPerShare = accumulatedRewardPerShare + (rewards / (totalSupply() == 0 ? 1 : totalSupply()));
        lastRewardTimestamp = block.timestamp;
        console.log("emission rate", emissionRate);
    }

    
}
