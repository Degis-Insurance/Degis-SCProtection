// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPremiumRewardPool.sol";

import "../libraries/DateTime.sol";

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
 */
contract WeightedFarmingPool {
    using DateTimeLibrary for uint256;
    using SafeERC20 for IERC20;

    // 4 decimals precision for weight
    uint256 public constant BASE_WEIGHT = 10000;

    uint256 public constant SCALE = 1e12;

    address public premiumRewardPool;
    address public policyCenter;

    uint256 public counter;

    struct PoolInfo {
        address[] tokens;
        uint256[] amount;
        uint256[] weight;
        uint256 shares;
        address rewardToken;
        uint256 lastRewardTimestamp;
        uint256 accRewardPerShare;
    }
    mapping(uint256 => PoolInfo) public pools;

    // pool id => year => month => daily amount
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) speed;

    struct UserInfo {
        uint256[] amount;
        uint256 share;
        uint256 rewardDebt;
    }
    mapping(uint256 => mapping(address => UserInfo)) public users;

    // Keccak256(poolId, token) => Whether supported
    // Ensure one token not be added for multiple times
    mapping(bytes32 => bool) public supported;

    event PoolAdded(uint256 poolId, address token);
    event NewTokenAdded(uint256 poolId, address token, uint256 weight);
    event PoolUpdated(uint256 poolId, uint256 accRewardPerShare);
    event WeightChanged(uint256 poolId);
    event Harvest(
        uint256 poolId,
        address user,
        address receiver,
        uint256 reward
    );

    constructor(address _premiumRewardPool) {
        premiumRewardPool = _premiumRewardPool;
    }

    function setPolicyCenter(address _policyCenter) public {
        policyCenter = _policyCenter;
    }

    function pendingReward(uint256 _id, address _user)
        external
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = pools[_id];
        UserInfo memory user = users[_id][_user];

        pending =
            (user.share * pool.accRewardPerShare) /
            SCALE -
            user.rewardDebt;
    }

    function addPool(address _rewardToken) external {
        uint256 currentId = ++counter;

        PoolInfo storage pool = pools[currentId];
        pool.rewardToken = _rewardToken;

        emit PoolAdded(currentId, _rewardToken);
    }

    function addToken(
        uint256 _id,
        address _token,
        uint256 _weight
    ) public {
        bytes32 key = keccak256(abi.encodePacked(_id, _token));
        require(!supported[key], "Already supported");

        supported[key] = true;
        pools[_id].tokens.push(_token);
        pools[_id].weight.push(_weight);

        emit NewTokenAdded(_id, _token, _weight);
    }

    function updateWeight(
        uint256 _id,
        address _token,
        uint256 _newWeight
    ) external {
        updatePool(_id);
        
        uint256 index = _getIndex(_id, _token);

        pools[_id].weight[index] = _newWeight;
    }

    function setWeight(uint256 _id, uint256[] calldata weights) external {
        PoolInfo storage pool = pools[_id];

        uint256 weightLength = weights.length;

        require(weightLength == pool.weight.length, "Wrong weight length");

        for (uint256 i; i < weightLength; ) {
            pool.weight[i] = weights[i];

            unchecked {
                ++i;
            }
        }

        emit WeightChanged(_id);
    }

    function updateRewardSpeed(
        uint256 _id,
        uint256 _newSpeed,
        uint256[] memory _years,
        uint256[] memory _months
    ) external {
        require(_years.length == _months.length, "Wrong length");
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
        require(
            msg.sender == policyCenter,
            "Only policyCenter can call stakedLiquidity"
        );

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
        require(
            msg.sender == policyCenter,
            "Only policyCenter can call stakedLiquidity"
        );

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
        require(_amount > 0, "Zero amount");
        require(_id <= counter, "Pool not exists");

        updatePool(_id);

        PoolInfo storage pool = pools[_id];
        UserInfo storage user = users[_id][_user];

        if (user.share > 0) {
            uint256 pending = (user.share * pool.accRewardPerShare) /
                SCALE -
                user.rewardDebt;

            uint256 actualReward = _safeRewardTransfer(
                pool.rewardToken,
                _user,
                pending
            );

            emit Harvest(_id, _user, _user, actualReward);
        }

        uint256 index = _getIndex(_id, _token);

        user.amount[index] += _amount;
        user.share += _amount * pool.weight[index];

        user.rewardDebt = (user.share * pool.accRewardPerShare) / SCALE;
    }

    function _withdraw(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _user
    ) internal {
        require(_amount > 0, "Zero amount");
        require(_id <= counter, "Pool not exists");

        updatePool(_id);

        PoolInfo storage pool = pools[_id];
        UserInfo storage user = users[_id][_user];

        if (user.share > 0) {
            uint256 pending = (user.share * pool.accRewardPerShare) /
                SCALE -
                user.rewardDebt;

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
        user.share -= _amount * pool.weight[index];

        user.rewardDebt = (user.share * pool.accRewardPerShare) / SCALE;
    }

    function updatePool(uint256 _id) public {
        PoolInfo storage pool = pools[_id];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }

        if (pool.shares > 0) {
            uint256 newReward = _updateReward(_id);

            pool.accRewardPerShare += newReward / pool.shares;

            pool.lastRewardTimestamp = block.timestamp;

            emit PoolUpdated(_id, pool.accRewardPerShare);
        } else {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
    }

    function harvest(uint256 _id, address _to) external {
        updatePool(_id);

        PoolInfo storage pool = pools[_id];
        UserInfo storage user = users[_id][msg.sender];

        uint256 pending = (user.share * pool.accRewardPerShare) /
            SCALE -
            user.rewardDebt;

        require(pending > 0, "No pending reward");

        uint256 actualReward = _safeRewardTransfer(
            pool.rewardToken,
            _to,
            pending
        );

        emit Harvest(_id, msg.sender, _to, actualReward);

        user.rewardDebt = (user.share * pool.accRewardPerShare) / SCALE;
    }

    /**
     * @notice Update reward for a pool
     *
     * @param _id Pool id
     */
    function _updateReward(uint256 _id) internal returns (uint256 totalReward) {
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

        // Distribute reward to Priority Pool
        IPremiumRewardPool(premiumRewardPool).distributeToken(
            pool.rewardToken,
            totalReward
        );
    }

    /**
     * @notice Update reward speed
     *
     * @param _id       Pool id
     * @param _months   Cover length in months
     * @param _newSpeed New speed to be added
     */
    function _updateRewardSpeed(
        uint256 _id,
        uint256 _months,
        uint256 _newSpeed
    ) internal {
        (uint256 currentY, uint256 currentM, ) = block
            .timestamp
            .timestampToDate();

        for (uint256 i; i < _months; ) {
            speed[_id][currentY][currentM] += _newSpeed;

            unchecked {
                if (++currentM > 12) {
                    ++currentY;
                    currentM = 1;
                }

                ++i;
            }
        }
    }

    function _safeRewardTransfer(
        address _token,
        address _to,
        uint256 _amount
    ) internal returns (uint256 actualAmount) {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        require(balance > 0, "Zero balance");

        if (_amount > balance) {
            actualAmount = balance;
        } else {
            actualAmount = _amount;
        }

        IERC20(_token).safeTransfer(_to, actualAmount);
    }

    function _getIndex(uint256 _id, address _token)
        internal
        view
        returns (uint256)
    {
        address[] memory allTokens = pools[_id].tokens;
        uint256 length = allTokens.length;

        for (uint256 i; i < length; ) {
            if (allTokens[i] == _token) return i;

            unchecked {
                ++i;
            }
        }

        revert("Not in the pool");
    }
}
