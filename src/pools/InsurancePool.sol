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
    
    // Time to distribute premium payments to liquidity providers
    uint256 public constant DISTRIBUTION_PERIOD = 30 days;

    // Time users have to claim payout when pool is liquidated
    uint256 public constant PAY_COVER_PERIOD = 10 days;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Address of insured token
    address public insuredToken;

    // Admin role. Performs set opearations on the contract.
    address public administrator;

    // if pool has been liquidated
    bool public liquidated;

    // max amount of bought protection in native tokens.
    uint256 public maxCapacity;

    // max time length in days of granted protection.
    uint256 public maxLength;

    // timestamp of pool creation.
    uint256 public startTime;

    //
    uint256 public priceRatio;
    // totalLiquidity is expressed in totalSupply()
    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public lastRewardTimestamp;
    uint256 public emssionEndTime;
    uint256 public emissionRate;
    uint256 public endLiquidationDate;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);
    event Liquidation(uint256 amount, uint256 endDate);
    event EmissionRateUpdated(uint256 rate);
    event RewardsUpdated(uint256 amount);
    event LiquidationEnded(uint256 timestamp);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _protocolToken,
        uint256 _maxCapacity,
        string memory _name,
        string memory _symbol,
        uint256 _priceRatio,
        address _administrator
    ) ERC20(_name, _symbol) {
        // token address insured by pool
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
        startTime = block.timestamp;
        priceRatio = _priceRatio;
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
     * @param _length Coverage length in days
     */
    function coveragePrice(uint256 _amount, uint256 _length)
        external
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
        // price in bps per year * amount of tokens to receive when pool is liquidated 
        // * lenght of coverage in days / year and 100 to get bps to percentage
            (priceRatio * _amount * _length) / (365 * 100);
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
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;
        uint256 acc = accumulatedRewardPerShare + rewards / totalSupply();
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

    function setIncidentReport(address _incidentReport) external override onlyRole {
        incidentReport = _incidentReport;
    }

    function setReinsurancePool(address _reinsurancePool)
        external
        override
        onlyRole
    {
        reinsurancePool = _reinsurancePool;
    }

    function setOnboardProposal(address _onboardProposal)
        external
        override
        onlyRole
    {
        onboardProposal = _onboardProposal;
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
     */
    function setPausedInsurancePool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == incidentReport),
            "Only owner or proposalCenter can call this function"
        );
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
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
    @notice Called when liqudity is provided, removed or coverage is bought.
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
    * @notice Update emission rate based on new premium comission to liquidity providers
    *
    * @param _premium premium given to liquidity providers
     */
    function updateEmissionRate(uint256 _premium) public {
        require(
            msg.sender == policyCenter,
            "Only pollicyCenter can update emission rate"
        );
        _updateEmissionRate(_premium);
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

        // set end liquidation date. users will have PAY_COVER_PERIOD days to claim payout.
        endLiquidationDate = block.timestamp + PAY_COVER_PERIOD;

        // emit event to notify users that pool has been liquidated.
        emit Liquidation(amount, endLiquidationDate);
    }


    function verifyLiquidationEnded() external {
        require(
            liquidated,
            "Pool has not been liquidated"
        );
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
    * @param _premium incoming new premium
     */
    function _updateEmissionRate(uint256 _premium) internal {
        // Update current reward taking into account new emission rate
        _updateRewards();
        // Get time to complete current pool of tokens emission to liquidity providers
        uint256 timeToFinishEmission = emssionEndTime > block.timestamp ?
                                       emssionEndTime - block.timestamp : 0;

        // Calculate new emission rate by adding new premium and redistributing previous emission
        // Throughout the time it takes to complete emission.
        if (timeToFinishEmission > 0) {
            emissionRate = ((emissionRate * timeToFinishEmission) + _premium) /
                                      DISTRIBUTION_PERIOD;
            // Update emission rate
        } else {
            // Update emission rate
            emissionRate = _premium / DISTRIBUTION_PERIOD;
        }
                                
        // update emission rate and emission ends
        emssionEndTime = block.timestamp + DISTRIBUTION_PERIOD;

        emit EmissionRateUpdated(emissionRate);
    }

    /**
     * @notice Update rewards
     */
    function _updateRewards() internal {
        if (totalSupply() == 0) {
            // if totalSupply is 0, no rewards can be paid
            // update last time rewards were claimed
            lastRewardTimestamp = block.timestamp;
            return;
        }
        // if no coverages have been bought in over 30 days,
        // discount time passed since the time that emission ends
        uint256 claimTimestamp = emssionEndTime < block.timestamp ?
                                 emssionEndTime : block.timestamp;
        // Calculate difference between claim time and last time rewards were claimed
        uint256 timeSinceLastReward = claimTimestamp - lastRewardTimestamp;

        // Calculate new reward
        uint256 rewards = timeSinceLastReward * emissionRate;

        // Update accumulated rewards given to each pool share
        // accumulated 
        accumulatedRewardPerShare =
            accumulatedRewardPerShare +
            rewards / totalSupply();
        lastRewardTimestamp = block.timestamp;

        // emit event to notify users that rewards have been updated
        emit RewardsUpdated(rewards);
    }

    function _setLiquidationStatus(bool _liquidated) internal {
        liquidated = _liquidated;
    }
}
