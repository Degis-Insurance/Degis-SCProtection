// SPDX-License-Identifier: MIT

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
    address public reinsurancePool;

    /**
     * @notice Buy new policies
     */
    function buyPolicy(
        uint256 _productId,
        uint256 _amount,
        uint256 _length
    ) external {}

    function claimPolicy() external {}

    function provide() external {}
}
