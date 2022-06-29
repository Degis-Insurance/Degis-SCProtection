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

import "../interfaces/IInsurancePool.sol";

pragma solidity ^0.8.13;

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
contract PolicyCenter {
    
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

    // productIds => address, updated once pools are deployed
    mapping(uint256 => address) poolIds;
    // or store insurance poools by index, productId would be the index
    // ReinsurancePool is pool 0
    address[] public insurancePools;
    /**
     * @notice Buy new policies
     */

    modifier poolExists(uint256 _poolId) {
        require(poolIds[_poolId] != address(0), "Pool not found");
        _;
    }
    function buyPolicy(
        uint256 _poolId,
        uint256 _amount,
        uint256 _length
    ) external poolExists(_poolId) {
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        pool.buyPolicy(_amount, _length);
    }
    
    
    function getPoolInfo(uint256 _poolId) external view poolExists(_poolId) {
        return IInsurancePool(insurancePools[_poolId]).poolInfo;
    }
    function getAvaiableDepositbyPool(address _poolId) external view poolExists(_poolId) {
        return IInsurancePool(insurancePools[_poolId]).getAvaiableDeposit();
    }
    function claimPayoff(uint256 _poolId, uint256 _amount) external {}
    function provideLiquidity(uint256 _poolId, uint256 _amount) external poolExists(_poolId) {
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        pool.provideLiquidity(_amount);
    }
    function removeLiquidity(uint256 _poolId, uint256 _amount) external poolExists(_poolId) {
        IInsurancePool pool = IInsurancePool(insurancePools[_poolId]);
        pool.removeLiquidity(_amount);
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
