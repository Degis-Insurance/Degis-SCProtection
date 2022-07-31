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

import "../util/ProtocolProtection.sol";

/**
 * @title Insurance Pool Factory
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the factory contract for deploying new insurance pools
 *         Each pool represents a project that has joined Degis Smart Contract Protection
 */
contract InsurancePool is ERC20, ProtocolProtection, Pausable {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant DISTRIBUTION_PERIOD = 30 days;

    // up to 25% discount if protection is bought for an entire year
    uint256 public constant DISCOUNT_DIVISOR = 1460;
    uint256 public constant PAY_COVER_PERIOD = 10 days;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public insuredToken;
    address public administrator;

    bool public liquidated;
    uint256 public maxCapacity;

    uint256 public maxLength;
    
    
    uint256 public startTime;
    uint256 public policyPricePerShield;
    // totalLiquidity is expressed in totalSupply()
    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public lastRewardTimestamp;
    uint256 public emissionRate;
    uint256 public endLiquidationDate;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event Liquidation(uint256 amount, uint256 endDate);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _name,
        string memory _symbol,
        uint256 _policyPricePerToken,
        address _administrator
    ) ERC20(_name, _symbol) {
        // token address insured by pool
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;
        policyPricePerShield = _policyPricePerToken;
        administrator = _administrator;
        maxLength = 90;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // allows owner, executor contract or administrator
    modifier onlyRole() {
        require(
            (msg.sender == owner()) ||
                (msg.sender == executor) ||
                (msg.sender == administrator),
            "Only owner, executor or administrator can call this function"
        );
        _;
    }

    // allows executor contract
    modifier onlyExecutor() {
        require(msg.sender == executor, "Only executor can call this function");
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice returns cost to buy coverage for a given period of time and amount of tokens
     *
     * @param _amount Amount being covered
     * @param _length Coverage length
     */
    function coveragePrice(uint256 _amount, uint256 _length)
        public
        view
        returns (uint256)
    {
        require(_amount > 0, "amount cannot be zero");
        require(_length > 0, "length cannot be zero");
        require(
            _length <= maxLength,
            "length cannot be greater than maxLength"
        );
        return
            (((policyPricePerShield * _amount * _length) / 1 days) *
                (DISCOUNT_DIVISOR + 1 - _length)) / DISCOUNT_DIVISOR;
    }

    /**
     * @notice Calculate your reward
     *
     * @param _amount   Amount in provided liquidity
     * @param _userDebt Amount of debt the user
     */
    function calculateReward(uint256 _amount, uint256 _userDebt)
        public
        view
        returns (uint256)
    {
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;
        uint256 acc = accumulatedRewardPerShare + (rewards / totalSupply());
        uint256 reward = (_amount * acc) - _userDebt;
        return reward;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    // overriden set functions to allow special roles to change set addresses
    function setMaxLength(uint256 _maxLength) external onlyRole {
        maxLength = _maxLength;
    }

    function setDeg(address _deg) external override onlyRole {
        deg = _deg;
    }

    function setVeDeg(address _veDeg) external override onlyRole {
        veDeg = _veDeg;
    }

    function setShield(address _shield) external override onlyRole {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external override onlyRole {
        policyCenter = _policyCenter;
    }

    function setReinsurancePool(address _reinsurancePool)
        external
        override
        onlyRole
    {
        reinsurancePool = _reinsurancePool;
    }

    function setProposalCenter(address _proposalCenter)
        external
        override
        onlyRole
    {
        proposalCenter = _proposalCenter;
    }

    function setExecutor(address _executor) external override onlyRole {
        executor = _executor;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory)
        external
        override
        onlyRole
    {
        insurancePoolFactory = _insurancePoolFactory;
    }

    /**
     * @notice sets if pool is paused
     * @param _paused if true paused, else not paused
     */
    function setPausedInsurancePool(bool _paused) external {
        _pause();
    }

    function setMaxCapacity(uint256 _maxCapacity) external onlyRole {
        maxCapacity = _maxCapacity;
    }

    /**
    @notice pools receive an administrator (address that deployed the Insurance Pool Factory)
    and passes it forward to the Insurance Pools the Factory deploys.
    @param _administrator address of the administrator
     */
    function setAdministrator(address _administrator) external onlyRole {
        administrator = _administrator;
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
    {
        require(!liquidated, "cannot provide new liquidity");
        require(_amount > 0, "amount should be greater than 0");
        require(
            msg.sender == policyCenter,
            "cannot provide liquidity directly to insurance pool"
        );

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
    {
        require(
            !liquidated,
            "Pool has been liquidated, cannot remove liquidity"
        );
        require(
            msg.sender == policyCenter,
            "cannot remove liquidity directly from insurance pool"
        );

        require(_amount > 0, "amount should be greater than 0");
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
    }

    /**
     * @notice Called when a coverage is bought on PolicyCenter. Only callable through policyCenter
     *
     * @param _paid Amount paid to insure amount of tokens
     */
    function updatePoolDistribution(uint256 _paid) external {
        require(
            msg.sender == policyCenter,
            "Only policyCenter can buy coverage"
        );
        require(_paid > 0, "paid should be greater than 0");
        totalDistributedReward += emissionRate * (block.timestamp - startTime);
        accumulatedRewardPerShare +=
            (_paid * (block.timestamp - startTime)) /
            (totalSupply() == 0 ? 1 : totalSupply());
        emissionRate = (_paid - totalDistributedReward) / DISTRIBUTION_PERIOD;
    }

    /**
    @notice called when liqudity is provided, removed or coverage is bought.
    updates all state variables to reflect current reward emission.
    */
    function updateRewards() public {
        require(
            msg.sender == policyCenter,
            "Only pollicyCenter can update rewards"
        );
        _updateRewards();
    }

    /**
    @notice sets this insurance pool to liquidated. Only callable by executor
    */
    function liquidatePool() external onlyExecutor {
        // changes the status of the insurance pool to liquidated and allows payout claims
        _setLiquidationStatus(true);
        // when liquidated, totalSupply does not change. liquidity providers keep LP tokens.
        // LP tokens represent their share of remaining liquidity after payout is done.
        uint256 amount = totalSupply();
        endLiquidationDate = block.timestamp + PAY_COVER_PERIOD;
        emit Liquidation(amount, endLiquidationDate);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Update rewards
     */
    function _updateRewards() internal {
        if (totalSupply() == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;

        accumulatedRewardPerShare =
            accumulatedRewardPerShare +
            (rewards / (totalSupply() == 0 ? 1 : totalSupply()));

        lastRewardTimestamp = block.timestamp;
    }

    function _setLiquidationStatus(bool _liquidated) internal {
        liquidated = _liquidated;
    }
}
