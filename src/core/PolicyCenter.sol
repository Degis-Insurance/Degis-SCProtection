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
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IInsurancePoolFactory.sol";
import "../interfaces/IPremiumVault.sol";
import "../interfaces/IProposalCenter.sol";
import "../interfaces/IComittee.sol";
import "../interfaces/IExecutor.sol";

/**
 * @title Policy Center
 *
 * @author Eric Lee (ylikp.ust@gmail.com)
 *
 * @notice This is the policy center for degis smart contract insurance
 *         Users can buy policies and get payoff here
 *         Sellers can provide liquidity and choose the pools to cover
 *
 */
contract PolicyCenter is Ownable {
    struct Coverage {
        uint256 _poolId;
        uint256 _amount;
        uint256 start;
        uint256 end;
        address signerAddress;
    }

    // should the LP provider be stored at this level?
    struct LiquidityProvider {
        uint256 amount;
        uint256 length;
        uint256 debt;
        uint256 poolId;
    }

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

    // productIds => address, updated once pools are deployed
    // ReinsurancePool is pool 0
    mapping(uint256 => address) public insurancePools;
    mapping(uint256 => uint256) public toSplitByPoolId;

    mapping(uint256 => uint256) public toInsuranceByPoolId;

    uint256[4] public premiumSplits;
    // amount in shield
    uint256 public treasury;

    constructor(address _reinsurancePool) {
        insurancePools[0] = _reinsurancePool;
        reinsurancePool = _reinsurancePool;
        // 5 % to treasury, 45% to insurance, 50% to reinsurance 0.03% to splitter
        premiumSplits = [499, 44999, 49999, 3];
    }

    modifier poolExists(uint256 _poolId) {
        require(insurancePools[_poolId] != address(0), "Pool not found");
        _;
    }

    function getPoolInfo(uint256 _poolId)
        public
        view
        poolExists(_poolId)
        returns (
            string memory,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        (
            string memory name,
            address insuredToken,
            uint256 maxCapacity,
            uint256 liquidity,
            uint256 claimable
        ) = IInsurancePool(insurancePools[_poolId]).poolInfo();
        return (name, insuredToken, maxCapacity, liquidity, claimable);
    }

    function isPoolAddress(address _poolAddress) public view returns (bool) {
        uint256 length = IInsurancePoolFactory(insurancePoolFactory)
            .getPoolCounter();
        for (uint256 i = 0; i < length; i++) {
            if (insurancePools[i] == _poolAddress) {
                return true;
            }
        }
        return false;
    }

    function getInsurancePoolById(uint256 _poolId)
        public
        view
        returns (address)
    {
        return insurancePools[_poolId];
    }

    function setDeg(address _deg) external onlyOwner {
        DEG = _deg;
    }

    function setVeDeg(address _veDeg) external onlyOwner {
        veDEG = _veDeg;
    }

    function setShield(address _shield) external onlyOwner {
        shield = _shield;
    }

    function setPolicyCenter(address _policyCenter) external onlyOwner {
        policyCenter = _policyCenter;
    }

    function setProposalCenter(address _proposalCenter) external onlyOwner {
        proposalCenter = _proposalCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external onlyOwner {
        reinsurancePool = _reinsurancePool;
    }

    function setExecutor(address _executor) external onlyOwner {
        executor = _executor;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory) external onlyOwner {
        insurancePoolFactory = _insurancePoolFactory;
    }

    function setPremiumSplit(
        uint256 _treasury,
        uint256 _insurance,
        uint256 _reinsurance,
        uint256 _splitter
    ) external onlyOwner {
        require(_treasury + _insurance + _reinsurance + _splitter == 10000);
        require(_treasury > 0, "has not given a treasury split");
        require(_insurance > 0, "has not given an insurance split");
        require(_reinsurance > 0, "has not given a reinsurance split");
        premiumSplits = [_treasury, _insurance, _reinsurance, _splitter];
    }

    /**
     * @notice Buy new policies
     */
    function buyCoverage(
        uint256 _poolId,
        uint256 _paid,
        uint256 _amount,
        uint256 _length
    ) external poolExists(_poolId) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_length > 0, "Length must be greater than 0");
        require(_poolId > 0, "PoolId must be greater than 0");
        require(
            _poolId <=
                IInsurancePoolFactory(insurancePoolFactory).getPoolCounter(),
            "PoolId must be less than or equal to the number of pools"
        );

        uint256 price = IInsurancePool(insurancePool).policyPrice(
            _poolId,
            _amount,
            _length
        );
        toSplitByPoolId[_poolId] = toSplitByPoolId[_poolId] + price;
        IERC20(shield).transferFrom(msg.sender, address(this), price);
        IInsurancePool(insurancePool).buyCoverage(
            _paid,
            _amount,
            _length,
            msg.sender
        );
    }

    function splitPremium(uint256 _poolId) external poolExists(_poolId) {
        require(toSplitByPoolId[_poolId] > 0, "No funds to split");
        uint256 totalSplit = toSplitByPoolId[_poolId];
        uint256 toPool = ((totalSplit * 4499) / 10000);
        uint256 toReinusrancePool = ((totalSplit * 4999) / 10000);
        uint256 toTreasury = ((totalSplit * 499) / 10000);
        uint256 toSplitter = ((totalSplit * 3) / 10000);

        IERC20(shield).transferFrom(
            address(this),
            insurancePools[_poolId],
            toPool
        );
        IInsurancePool(insurancePools[_poolId]).addPremium(toPool);
        IERC20(shield).transferFrom(
            address(this),
            reinsurancePool,
            toReinusrancePool
        );
        treasury = treasury + toTreasury;
        IERC20(shield).transferFrom(address(this), msg.sender, toSplitter);
    }

    function claimPayout(uint256 _poolId, uint256 _amount) external {
        require(
            IInsurancePool(insurancePools[_poolId]).isHalted(),
            "Pool is not claimable"
        );
        IInsurancePool(insurancePools[_poolId]).claimPayout(_amount);
    }

    function provideLiquidity(uint256 _poolId, uint256 _amount)
        external
        poolExists(_poolId)
    {
        require(_amount > 0, "Amount must be greater than 0");

        if (_poolId == 0) {
            IReinsurancePool(reinsurancePool).provideLiquidity(
                _amount,
                msg.sender
            );
            IERC20(shield).transferFrom(msg.sender, reinsurancePool, _amount);
        } else {
            IInsurancePool(insurancePools[_poolId]).provideLiquidity(
                _amount,
                msg.sender
            );
            IERC20(shield).transferFrom(
                msg.sender,
                insurancePools[_poolId],
                _amount
            );
        }
    }

    function removeLiquidity(uint256 _poolId, uint256 _amount)
        external
        poolExists(_poolId)
    {
        IInsurancePool(insurancePools[_poolId]).removeLiquidity(
            _amount,
            msg.sender
        );
    }

    function addPoolId(uint256 _poolId, address _address) external {
        require(
            msg.sender == insurancePoolFactory,
            "not requested from by Insurance Pool Factory"
        );
        insurancePools[_poolId] = _address;
    }

    function rewardReporter(address _reporter) external {
        require(
            msg.sender == proposalCenter,
            "not requested from by Proposal Center"
        );
        uint256 reward = (treasury * 1000) / 10000;
        treasury -= reward;
        IERC20(shield).transfer(_reporter, reward);
    }

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
