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

import "../interfaces/IInsurancePool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
    }

    address public reinsurancePool;
    address public insurancePoolFactory;
    // productIds => address, updated once pools are deployed
    // ReinsurancePool is pool 0
    mapping(uint256 => address) public poolIds;
    mapping(uint256 => uint256) public toSplitByPoolId;

    mapping(uint256 => uint256) public toInsuranceByPoolId;

    uint256[4] public premiumSplits;
    // amount in shield
    uint256 public treasury;

    constructor(address _reinsurancePool) public {
        poolIds[0] = _reinsurancePool;
        // 5 % to treasury, 45% to insurance, 50% to reinsurance 0.03% to splitter
        premiumSplits = [499, 44999, 49999, 3];
    }

    modifier poolExists(uint256 _poolId) {
        require(poolIds[_poolId] != address(0), "Pool not found");
        _;
    }
    
    function getPoolInfo(uint256 _poolId)
        public
        view
        poolExists(_poolId)
        returns (
            string,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        (
            string name,
            address insuredToken,
            uint256 maxCapacity,
            uint256 liquidity,
            uint256 claimable
        ) = IInsurancePool(poolIds[_poolId]).poolInfo();
        return (name, insuredToken, maxCapacity, liquidity, claimable);
    }

    function isPoolAddress(address _poolAddress) public view returns (bool) {
        uint256 length = IInsurancePoolFactory(insurancePoolFactory)
            .poolCounter;
        for (uint256 i = 0; i < length; i++) {
            if (poolIds[i] == _poolAddress) {
                return true;
            }
        }
        return false;
    }

    function setPremiumSplit(uint256 _treasury, uint256 _insurance, uint256 _reinsurance, uint256 _splitter) external ownerOnly {
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
        uint256 _amount,
        uint256 _length
    ) external poolExists(_poolId) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_length > 0, "Length must be greater than 0");
        toSplitByPoolId = toSplit.add(_amount);

        PremiumVault(premiumVaultAddress).coverageBought(
            msg.sender,
            _poolId,
            _amount,
            _length
        );
        ERC20(shield).transferFrom(msg.sender, address(this), _amount);
    }

    function splitFunds(address _poolId) external poolExists(_poolId) {
        require(toSplitByPoolId[_poolId] > 0, "No funds to split");
        uint256 totalSplit = toSplitByPoolId[_poolId];
        uint256 toPool = ((totalSplit * 4499) / 10000);
        uint256 toReinusrancePool = ((totalSplit * 4999) / 10000);
        uint256 toTreasury = ((totalSplit * 499) / 10000);
        uint256 toSplitter = ((totalSplit * 3) / 10000);

        IERC20(shield).transferFrom(address(this), poolIds[_poolId], toPool);
        IERC20(shield).transferFrom(
            address(this),
            reinsurancePool,
            toReinusrancePool
        );
        treasury = treasury.add(toTreasury);
        IERC20(shield).transferFrom(address(this), msg.sender, toSplitter);
    }

    function addDEGToTreasury(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        
        treasury = treasury.add(_amount);
    }

    function awardReporter(address _reporter, uint256 _poolId) external {
        require(msg.sender == proposalCenterAddress, "not requested from by Proposal Center");

    }

    function getAvaiableDepositbyPool(address _poolId)
        external
        view
        poolExists(_poolId)
    {
        return IInsurancePool(insurancePools[_poolId]).getAvaiableDeposit();
    }

    function claimPayout(uint256 _poolId, uint256 _amount) external {
        require(
            IInsurancePool(insurancePools[_poolId]).claimable(),
            "Pool is not claimable"
        );
        IInsurancePool(insurancePools[_poolId]).claimPayout(_amount, msg.sender);
    }

    function provideLiquidity(uint256 _poolId, uint256 _amount)
        external
        poolExists(_poolId)
    {
        require(_amount > 0, "Amount must be greater than 0");

        if (_poolId == 0) {
            IReinsurancePool(reinsurancePool).provideLiquidity(_amount, msg.sender);
            ERC20(shield).transfer(msg.sender, reinsurancePool, _amount);
        } else {
            IInsurancePool pool = IInsurancePool(insurancePools[_poolId]).provideLiquidity(_amount, msg.sender);
            ERC20(shield).transfer(msg.sender, insurancePools[_poolId], _amount);
        }
       
    }

    function removeLiquidity(uint256 _poolId, uint256 _amount)
        external
        poolExists(_poolId)
    {
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        pool.removeLiquidity(_amount);
    }

    function addPoolId(uint256 _poolId, address _address) external factoryOnly {
        poolIds[_poolId] = _address;
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
