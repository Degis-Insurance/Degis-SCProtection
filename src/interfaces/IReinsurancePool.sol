// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IReinsurancePool {
    function setShield(address _shield) external;

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function provideLiquidity(uint256 _amount, address _provider) external;

    function removeLiquidity(uint256 _amount, address _provider) external;

    function reinsurePool(uint256 _amount, address _address) external;

    /**
     * @notice Move liquidity to another pool to be used for reinsurance.
     * @param _amount Amount of liquidity to move.
     * @param _poolId Id of the pool to move the liquidity to.
     */
    function moveLiquidity(uint256 _poolId, uint256 _amount) external;

    function setPausedReinsurancePool(bool _paused) external;
}
