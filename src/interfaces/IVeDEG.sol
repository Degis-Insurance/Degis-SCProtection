// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the VeDEG
 */
interface IVeDEG is IERC20 {
    // Get the locked amount of a user's veDeg
    function locked(address _user) external view returns (uint256);

    // Lock veDEG
    function lockVeDEG(address _to, uint256 _amount) external;

    // Unlock veDEG
    function unlockVeDEG(address _to, uint256 _amount) external;
}
