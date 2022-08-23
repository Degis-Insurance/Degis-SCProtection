// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Premium Reward Pool
 *
 *         Temporarily store the shield reward for Protection Pool
 *                     store the token reward for Priority Pool
 */
contract PremiumRewardPool {
    address public factory;

    address public protectionPool;

    address public shield;

    // Pool address => Reward token
    mapping(address => address) public rewardToken;

    event ShieldDistributed(uint256 amount);
    event TokenDistributed(address token, uint256 amount);
    event RewardTokenRegistered(address pool, address token);

    constructor(
        address _shield,
        address _factory,
        address _protectionPool
    ) {
        shield = _shield;
        factory = _factory;
        protectionPool = _protectionPool;
    }

    /**
    * @notice Distributes shield to Protection Pool
    *
    * @param _amount          Amount of shield to distribute
    */
    function distributeShield(uint256 _amount) external {
        require(msg.sender == protectionPool, "Only protection pool");
        require(_amount > 0, "Zero amount to transfer");

        IERC20(shield).transfer(protectionPool, _amount);

        emit ShieldDistributed(_amount);
    }

    /**
    * @notice Distributes given token to one of the Priority Pools
    *
    * @param _token         Token address to distribute
    * @param _amount        Amount of shield to distribute
    */
    function distributeToken(address _token, uint256 _amount) external {
        require(_token == rewardToken[msg.sender], "Wrong priority pool");
        require(_amount > 0, "Zero amount to transfer");

        IERC20(_token).transfer(msg.sender, _amount);

        emit TokenDistributed(_token, _amount);
    }

    /**
    * @notice Registers a Priority Pool when it is deployed
    * @param _pool          Priority Pool address
    * @param _token         Reward token address
    */
    function register(address _pool, address _token) external {
        require(msg.sender == factory, "Only factory");

        rewardToken[_pool] = _token;

        emit RewardTokenRegistered(_pool, _token);
    }
}
