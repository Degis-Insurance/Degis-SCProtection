// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/ICoverRightTokenFactory.sol";
import "../interfaces/ICoverRightToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Payout Pool
 *
 *         Every time there is a report passed, some assets will be moved to this pool
 *         It is stored as a Payout struct
 *         - amount Total amount of this payout
 *         - remaining Remaining amount
 *         - endTimestamp After this timestamp, no more claims
 *         - ratio Max ratio of a user's crToken
 */
contract PayoutPool {
    uint256 public constant SCALE = 1e12;

    uint256 public constant CLAIM_PERIOD = 7 days;

    address public shield;

    uint256 public payoutCounter;
    address public crFactory;

    address public policyCenter;

    struct Payout {
        uint256 amount;
        uint256 remaining;
        uint256 endTiemstamp;
        uint256 ratio;
    }
    // Payout id => Payout info
    mapping(uint256 => Payout) public payouts;

    function newPayout(uint256 _amount, uint256 _ratio) external {
        uint256 currentPayoutId = ++payoutCounter;
        Payout storage payout = payouts[currentPayoutId];

        payout.amount = _amount;
        payout.endTiemstamp = block.timestamp + CLAIM_PERIOD;
        payout.ratio = _ratio;
    }

    // Claim the payout with crTokens
    function claim(
        address _user,
        uint256 _poolId,
        uint256 _expiry
    ) external {
        require(msg.sender == policyCenter, "Only policy center");

        bytes32 salt = keccak256(abi.encodePacked(_poolId, _expiry));

        address crToken = ICoverRightTokenFactory(crFactory).saltToAddress(
            salt
        );

        uint256 ava = ICoverRightToken(crToken).getClaimableOf(msg.sender);

        // TODO: add remaining payout check
        // TODO: how to store the payout id
        uint256 id;
        IERC20(shield).transfer(_user, (ava * payouts[id].ratio) / SCALE);
    }
}
