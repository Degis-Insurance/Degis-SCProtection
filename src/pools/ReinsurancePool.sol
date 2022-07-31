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

import "../util/ProtocolProtection.sol";

/**
 * @title Reinsurance Pool
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the reinsurance pool contract for degis Protocol Protection
 *         Users can provide liquidity to it through the Policy Center.
 *         If the insurance pool is unable to fulfil the insurance, the reinsurance pool
 *         will be able to provide the insurance to the user.
 */
contract ReinsurancePool is ERC20("ReinsurancePool", "RP"), ProtocolProtection {

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant DISTRIBUTION_PERIOD = 30 days;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    struct PoolInfo {
        address protocolAddress;
        uint256 proportion;
    }
    mapping(address => PoolInfo) public pools;

    struct Liquidity {
        uint256 amount;
        uint256 userDebt;
        uint256 lastClaim;
    }
    mapping(address => Liquidity) public liquidities;

    bool public insurancePoolLiquidated;
    bool public paused;

    uint256 public totalDistributedReward;
    uint256 public accumulatedRewardPerShare;
    uint256 public lastRewardTimestamp;
    uint256 public emissionRate;

    uint256 public maxCapacity;
    uint256 public startTime;
    uint256 public policyPricePerShield;
    //totalLiquidity is expressed in totalSupply()
    uint256 public endLiquidationDate;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MoveLiquidity(uint256 poolId, uint256 amount);
    event LiquidityProvision(uint256 amount, address sender);
    event LiquidityRemoved(uint256 amount, address sender);

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // only allows to be calle from a pool
    modifier poolOnly() {
        require(
            IPolicyCenter(policyCenter).isPoolAddress(msg.sender),
            "Pool not found"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Returns the to be rewarded by reinsurance pool
     * @param _amount   amount of liquidity provided by the user
     * @param _userDebt amount of debt the user has to the pool
     * @return reward   amount to receive considering amount and userDebt
     */
    function calculateReward(uint256 _amount, uint256 _userDebt)
        public
        view
        returns (uint256)
    {
        if (totalSupply() == 0) {
            return 0;
        }
        uint256 time = block.timestamp - lastRewardTimestamp;
        uint256 rewards = time * emissionRate;
        uint256 acc = accumulatedRewardPerShare + (rewards / totalSupply());
        uint256 reward = (_amount * acc) - _userDebt;
        return reward;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
    @notice terminate liquidation period on reinsurance pool only
    */
    function endLiquidationPeriod() external onlyOwner {
        insurancePoolLiquidated = false;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
    @notice mints liquidity tokens. Only callable through policyCenter
    @param _amount      token being insured
    @param _provider    liquidity provider adress
    */
    function provideLiquidity(uint256 _amount, address _provider) external {
        require(_amount > 0, "amount should be greater than 0");
        require(
            msg.sender == policyCenter,
            "cannot provide liquidity directly to insurance pool"
        );
        _mint(_provider, _amount);
        emit LiquidityProvision(_amount, _provider);
    }

    /**
    @notice burns liquidity tokens. Only callable through policyCenter
    @param _amount      token being insured
    @param _provider    liquidity provider adress
    */
    function removeLiquidity(uint256 _amount, address _provider) external {
        require(_amount <= totalSupply(), "amount exceeds totalSupply");
        require(
            block.timestamp >= liquidities[msg.sender].lastClaim + 604800,
            "cannot remove liquidity within 7 days of last claim"
        );
        require(_amount > 0, "amount should be greater than 0");
        require(
            msg.sender == policyCenter,
            "liquidity can only be provide through policy center"
        );
        require(!paused, "cannot remove liquidity while paused");
        _burn(_provider, _amount);
        emit LiquidityRemoved(_amount, _provider);
    }

    /**
    @notice provides liquidity to pools in need of it. Only callable by Pools
    @param _amount      token being insured
    @param _address     address of covered wallet
    */
    function reinsurePool(uint256 _amount, address _address) external poolOnly {
        require(_amount > 0, "amount should be greater than 0");
        IERC20(shield).transferFrom(address(this), _address, _amount);
    }

    /**
     * @notice  Move liquidity to another pool to be used for reinsurance,
                reducing gas costs during liquidation period.
     * @param _amount Amount of liquidity to transfer to insurance pool
     * @param _poolId Id of the pool to move the liquidity to.
     */
    function moveLiquidity(uint256 _poolId, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "Amount must be greater than 0");
        address poolAddress = IPolicyCenter(policyCenter).getInsurancePoolById(
            _poolId
        );
        require(poolAddress != address(0), "Pool not found");

        IERC20(shield).transferFrom(address(this), poolAddress, _amount);
        emit MoveLiquidity(_poolId, _amount);
    }

    /**
     * @notice Sets paused state of the reinsurance pool
     * @param _paused true if paused, false if not.
     */
    function setPausedReinsurancePool(bool _paused) external {
        require(
            (msg.sender == owner()) || (msg.sender == proposalCenter),
            "Only owner or proposalCenter can call this function"
        );
        paused = _paused;
    }

    /**
    @notice called when a coverage is bought on PolicyCenter. Only callable through policyCenter
    @param _paid amount paid to insure amount of tokens
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
}
