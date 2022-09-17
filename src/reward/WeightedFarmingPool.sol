// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/DateTime.sol";
import "../interfaces/IPriorityPoolFactory.sol";

import "./WeightedFarmingPoolEventError.sol";
import "./WeightedFarmingPoolDependencies.sol";

import "forge-std/console.sol";

/**
 * @notice Weighted Farming Pool
 *
 *         Weighted farming pool support multiple tokens to earn the same reward
 *         Different tokens will have different weights when calculating rewards
 *
 *
 *         Native token premiums will be transferred to this pool
 *         The distribution is in the way of "farming" but with multiple tokens
 *
 *         Different generations of PRI-LP-1-JOE-G1
 *
 *         About the scales of variables:
 *         - weight            SCALE
 *         - share             SCALE
 *         - accRewardPerShare SCALE * SCALE / SCALE = SCALE
 *         - rewardDebt        SCALE * SCALE / SCALE = SCALE
 *         So pendingReward = ((share * acc) / SCALE - debt) / SCALE
 */
contract WeightedFarmingPool is
    WeightedFarmingPoolEventError,
    Initializable,
    WeightedFarmingPoolDependencies
{
    using DateTimeLibrary for uint256;
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant SCALE = 1e12;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public counter;

    struct PoolInfo {
        address[] tokens; // Token addresses (PRI-LP)
        uint256[] amount; // Token amounts
        uint256[] weight; // Weight for each token
        uint256 shares; // Total shares (share = amount * weight)
        address rewardToken; // Reward token address
        uint256 lastRewardTimestamp; // Last reward timestamp
        uint256 accRewardPerShare; // Accumulated reward per share (not per token)
    }
    // Pool id => Pool info
    mapping(uint256 => PoolInfo) public pools;

    // Pool id => Year => Month => Speed
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))
        public speed;

    struct UserInfo {
        uint256[] amount; // Amount of each token
        uint256 shares; // Total shares (share = amount * weight)
        uint256 rewardDebt; // Reward debt
    }
    // Pool Id => User address => User Info
    mapping(uint256 => mapping(address => UserInfo)) public users;

    // Keccak256(poolId, token) => Whether supported
    // Ensure one token not be added for multiple times
    mapping(bytes32 => bool) public supported;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    // constructor(address _policyCenter, address _priorityPoolFactory) {
    //     policyCenter = _policyCenter;
    //     priorityPoolFactory = _priorityPoolFactory;
    // }

    function initialize(address _policyCenter, address _priorityPoolFactory)
        public
        initializer
    {
        policyCenter = _policyCenter;
        priorityPoolFactory = _priorityPoolFactory;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier isPriorityPool() {
        require(
            IPriorityPoolFactory(priorityPoolFactory).poolRegistered(
                msg.sender
            ),
            "Only Priority Pool"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    // @audit Add view functions for user lp amount
    function getUserLPAmount(uint256 _poolId, address _user)
        external
        view
        returns (uint256[] memory)
    {
        return users[_poolId][_user].amount;
    }

    function getPoolArrays(uint256 _poolId)
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        PoolInfo storage pool = pools[_poolId];
        return (pool.tokens, pool.amount, pool.weight);
    }

    // TODO: add owner or remove this
    function setPolicyCenter(address _policyCenter) public {
        policyCenter = _policyCenter;
    }

    // TODO: add owner or remove this
    function setPriorityPoolFactory(address _priorityPoolFactory) external {
        priorityPoolFactory = _priorityPoolFactory;
    }

    /**
     * @notice Pending reward
     *
     * @param _id   Pool id
     * @param _user User's address
     *
     * @return pending Pending reward in native token
     */
    function pendingReward(uint256 _id, address _user)
        external
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = pools[_id];
        UserInfo memory user = users[_id][_user];

        pending =
            ((user.shares * pool.accRewardPerShare) / SCALE - user.rewardDebt) /
            SCALE;
    }

    /**
     * @notice Register a new famring pool for priority pool
     *
     * @param _rewardToken Reward token address (protocol native token)
     */
    function addPool(address _rewardToken) external {
        uint256 currentId = ++counter;

        PoolInfo storage pool = pools[currentId];
        pool.rewardToken = _rewardToken;

        emit PoolAdded(currentId, _rewardToken);
    }

    /**
     * @notice Register Pri-LP token
     *         Called when new generation of PRI-LP tokens are deployed
     *
     * @param _id     Pool Id
     * @param _token  Priority pool lp token address
     * @param _weight Weight of the token in the pool
     */
    function addToken(
        uint256 _id,
        address _token,
        uint256 _weight
    ) public {
        bytes32 key = keccak256(abi.encodePacked(_id, _token));
        if (supported[key]) revert WeightedFarmingPool__AlreadySupported();

        // Record as supported
        supported[key] = true;

        pools[_id].tokens.push(_token);
        pools[_id].weight.push(_weight);

        emit NewTokenAdded(_id, _token, _weight);
    }

    /**
     * @notice Update the weight of a token in a given pool
     *
     * @param _id        Pool Id
     * @param _token     Token address
     * @param _newWeight New weight of the token in the pool
     */
    function updateWeight(
        uint256 _id,
        address _token,
        uint256 _newWeight
    ) external {
        updatePool(_id);

        uint256 index = _getIndex(_id, _token);

        pools[_id].weight[index] = _newWeight;
    }

    /**
     * @notice Sets the weight for a given array of tokens in a given pool
     * @param _id            Pool Id
     * @param _weights       Array of weights of the tokens in the pool
     */
    function setWeight(uint256 _id, uint256[] calldata _weights) external {
        PoolInfo storage pool = pools[_id];

        uint256 weightLength = _weights.length;

        if (weightLength != pool.weight.length)
            revert WeightedFarmingPool__WrongWeightLength();

        for (uint256 i; i < weightLength; ) {
            pool.weight[i] = _weights[i];

            unchecked {
                ++i;
            }
        }

        emit WeightChanged(_id);
    }

    /**
     * @notice Update reward speed when new premium income
     *
     * @param _id       Pool id
     * @param _newSpeed New speed (SCALED)
     * @param _years    Years to be updated
     * @param _months   Months to be updated
     */
    function updateRewardSpeed(
        uint256 _id,
        uint256 _newSpeed,
        uint256[] memory _years,
        uint256[] memory _months
    ) external {
        if (_years.length != _months.length)
            revert WeightedFarmingPool__WrongDateLength();

        uint256 length = _years.length;
        for (uint256 i; i < length; ) {
            speed[_id][_years[i]][_months[i]] += _newSpeed;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Deposit from Policy Center
     *         No need for approval
     */
    function depositFromPolicyCenter(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _user
    ) external {
        if (msg.sender != policyCenter)
            revert WeightedFarmingPool__OnlyPolicyCenter();

        _deposit(_id, _token, _amount, _user);
    }

    /**
     * @notice Directly deposit (need approval)
     */
    function deposit(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _user
    ) external {
        _deposit(_id, _token, _amount, _user);

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawFromPolicyCenter(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _user
    ) external {
        if (msg.sender != policyCenter)
            revert WeightedFarmingPool__OnlyPolicyCenter();

        _withdraw(_id, _token, _amount, _user);
    }

    function withdraw(
        uint256 _id,
        address _token,
        uint256 _amount
    ) external {
        _withdraw(_id, _token, _amount, msg.sender);
    }

    /**
     * @notice Deposit PRI-LP tokens
     *
     * @param _id     Farming pool id
     * @param _token  PRI-LP token address
     * @param _amount PRI-LP token amount
     * @param _user   Real user address
     */
    function _deposit(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _user
    ) internal {
        if (_amount == 0) revert WeightedFarmingPool__ZeroAmount();
        if (_id > counter) revert WeightedFarmingPool__InexistentPool();

        updatePool(_id);

        PoolInfo storage pool = pools[_id];
        UserInfo storage user = users[_id][_user];

        if (user.shares > 0) {
            uint256 pending = ((user.shares * pool.accRewardPerShare) /
                SCALE -
                user.rewardDebt) / SCALE;

            uint256 actualReward = _safeRewardTransfer(
                pool.rewardToken,
                _user,
                pending
            );

            emit Harvest(_id, _user, _user, actualReward);
        }

        uint256 index = _getIndex(_id, _token);

        // check if current index exists for user
        // index is 0, push
        // length <= index
        if (user.amount.length < index + 1) {
            user.amount.push(0);
        }

        if (pool.amount.length < index + 1) {
            pool.amount.push(0);
        }

        // Update user amount for this gen lp token
        user.amount[index] += _amount;
        user.shares += _amount * pool.weight[index];

        // Update pool amount for this gen lp token
        pool.amount[index] += _amount;
        pool.shares += _amount * pool.weight[index];

        user.rewardDebt = (user.shares * pool.accRewardPerShare) / SCALE;
    }

    function _withdraw(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _user
    ) internal {
        if (_amount == 0) revert WeightedFarmingPool__ZeroAmount();
        if (_id > counter) revert WeightedFarmingPool__InexistentPool();
        updatePool(_id);

        PoolInfo storage pool = pools[_id];
        UserInfo storage user = users[_id][_user];

        if (user.shares > 0) {
            uint256 pending = ((user.shares * pool.accRewardPerShare) /
                SCALE -
                user.rewardDebt) / SCALE;

            uint256 actualReward = _safeRewardTransfer(
                pool.rewardToken,
                _user,
                pending
            );

            emit Harvest(_id, _user, _user, actualReward);
        }

        IERC20(_token).transfer(_user, _amount);

        uint256 index = _getIndex(_id, _token);

        user.amount[index] -= _amount;
        user.shares -= _amount * pool.weight[index];

        pool.amount[index] -= _amount;
        pool.shares -= _amount * pool.weight[index];

        user.rewardDebt = (user.shares * pool.accRewardPerShare) / SCALE;
    }

    function updatePool(uint256 _id) public {
        PoolInfo storage pool = pools[_id];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }

        if (pool.shares > 0) {
            uint256 newReward = _updateReward(_id);

            // accRewardPerShare has 1 * SCALE
            pool.accRewardPerShare += (newReward * SCALE) / pool.shares;

            pool.lastRewardTimestamp = block.timestamp;

            emit PoolUpdated(_id, pool.accRewardPerShare);
        } else {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
    }

    function harvest(uint256 _id, address _to) external {
        if (_id > counter) revert WeightedFarmingPool__InexistentPool();

        updatePool(_id);

        PoolInfo storage pool = pools[_id];
        UserInfo storage user = users[_id][msg.sender];

        uint256 pending = ((user.shares * pool.accRewardPerShare) /
            SCALE -
            user.rewardDebt) / SCALE;

        uint256 actualReward = _safeRewardTransfer(
            pool.rewardToken,
            _to,
            pending
        );

        emit Harvest(_id, msg.sender, _to, actualReward);

        user.rewardDebt = (user.shares * pool.accRewardPerShare) / SCALE;
    }

    /**
     * @notice Update reward for a pool
     *
     * @param _id Pool id
     */
    function _updateReward(uint256 _id)
        internal
        view
        returns (uint256 totalReward)
    {
        PoolInfo storage pool = pools[_id];

        uint256 currentTime = block.timestamp;
        uint256 lastRewardTime = pool.lastRewardTimestamp;

        (uint256 lastY, uint256 lastM, uint256 lastD) = lastRewardTime
            .timestampToDate();

        (uint256 currentY, uint256 currentM, ) = currentTime.timestampToDate();

        uint256 monthPassed = currentM - lastM;

        // In the same month, use current month speed
        if (monthPassed == 0) {
            totalReward +=
                (currentTime - lastRewardTime) *
                speed[_id][currentY][currentM];
        }
        // Across months, use different months' speed
        else {
            for (uint256 i; i < monthPassed + 1; ) {
                // First month reward
                if (i == 0) {
                    // End timestamp of the first month
                    uint256 endTimestamp = DateTimeLibrary
                        .timestampFromDateTime(lastY, lastM, lastD, 23, 59, 59);
                    totalReward +=
                        (endTimestamp - lastRewardTime) *
                        speed[_id][lastY][lastM];
                }
                // Last month reward
                else if (i == monthPassed) {
                    uint256 startTimestamp = DateTimeLibrary
                        .timestampFromDateTime(lastY, lastM, 1, 0, 0, 0);

                    totalReward +=
                        (currentTime - startTimestamp) *
                        speed[_id][lastY][lastM];
                }
                // Middle month reward
                else {
                    uint256 daysInMonth = DateTimeLibrary._getDaysInMonth(
                        lastY,
                        lastM
                    );

                    totalReward +=
                        (DateTimeLibrary.SECONDS_PER_DAY * daysInMonth) *
                        speed[_id][lastY][lastM];
                }

                unchecked {
                    if (++lastM > 12) {
                        ++lastY;
                        lastM = 1;
                    }

                    ++i;
                }
            }
        }
    }

    /**
     * @notice Safely transfers reward to a user address
     *
     * @param _token  Reward token address
     * @param _to     Address to send reward to
     * @param _amount Amount to send
     */
    function _safeRewardTransfer(
        address _token,
        address _to,
        uint256 _amount
    ) internal returns (uint256 actualAmount) {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        // @audit remove this check
        // require(balance > 0, "Zero balance");

        if (_amount > balance) {
            actualAmount = balance;
        } else {
            actualAmount = _amount;
        }

        IERC20(_token).safeTransfer(_to, actualAmount);
    }

    /**
     * @notice Returns the index of Cover Right token given a pool id and crtoken address
     * @param _id            Pool id
     * @param _token         Address of Cover Right token
     */
    function _getIndex(uint256 _id, address _token)
        internal
        view
        returns (uint256 index)
    {
        address[] memory allTokens = pools[_id].tokens;
        uint256 length = allTokens.length;

        for (uint256 i; i < length; ) {
            if (allTokens[i] == _token) {
                index = i;
                break;
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        // revert WeightedFarmingPool__NotInPool();
    }
}
