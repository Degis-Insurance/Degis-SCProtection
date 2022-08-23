// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/ICoverRightTokenFactory.sol";
import "../interfaces/ICoverRightToken.sol";
import "../interfaces/IVeDEG.sol";
import "../interfaces/IPriorityPool.sol";

/**
 * @notice Payout Pool
 *
 *         Every time there is a report passed, some assets will be moved to this pool
 *         It is stored as a Payout struct
 *         - amount       Total amount of this payout
 *         - remaining    Remaining amount
 *         - endTimestamp After this timestamp, no more claims
 *         - ratio        Max ratio of a user's crToken
 */
contract PayoutPool {
    uint256 public constant SCALE = 1e12;

    uint256 public constant CLAIM_PERIOD = 30 days;

    address public shield;

    address public crFactory;

    address public policyCenter;

    struct Payout {
        uint256 amount;
        uint256 remaining;
        uint256 endTiemstamp;
        uint256 ratio;
        address priorityPool;
    }
    // Pool id => Generation => Payout
    mapping(uint256 => mapping(uint256 => Payout)) public payouts;

    event NewPayout(
        uint256 _poolId,
        uint256 _generation,
        uint256 _amount,
        uint256 _ratio
    );

    /**
     * @notice Registers new Payout in Payout Pool
     * @param _poolId            Pool Id
     * @param _generation        Generation of priority pool (1 if no liquidations occurred)
     * @param _amount         	Amount of tokens to be registered
     * @param _ratio         	Current ratio payout has been registered at
     * @param _poolAddress       Address of priority pool
     */
    function newPayout(
        uint256 _poolId,
        uint256 _generation,
        uint256 _amount,
        uint256 _ratio,
        address _poolAddress
    ) external {
        Payout storage payout = payouts[_poolId][_generation];

        payout.amount = _amount;
        payout.endTiemstamp = block.timestamp + CLAIM_PERIOD;
        payout.ratio = _ratio;
        payout.priorityPool = _poolAddress;

        emit NewPayout(_poolId, _generation, _amount, _ratio);
    }

    /**
     * @notice Claim payout for a user
     * @param _user             User address
     * @param _crToken         	Cover right token address
     * @param _poolId           Pool Id
     * @param _generation       Generation of priority pool (1 if no liquidations occurred)
     */
    function claim(
        address _user,
        address _crToken,
        uint256 _poolId,
        uint256 _generation
    ) external returns (uint256 claimed, uint256 newGenerationCRAmount) {
        require(msg.sender == policyCenter, "Only policy center");

        Payout storage payout = payouts[_poolId][_generation];

        uint256 expiry = ICoverRightToken(_crToken).expiry();

        bytes32 salt = keccak256(
            abi.encodePacked(_poolId, expiry, _generation)
        );
        require(
            ICoverRightTokenFactory(crFactory).saltToAddress(salt) == _crToken,
            "Wrong cr token"
        );

        uint256 claimableBalance = ICoverRightToken(_crToken).getClaimableOf(
            _user
        );
        uint256 claimable = (claimableBalance * payout.ratio) / 10000;

        uint256 coverIndex = IPriorityPool(payout.priorityPool).coverIndex();

        claimed = (claimable * coverIndex) / SCALE;

        ICoverRightToken(_crToken).burn(
            _poolId,
            _user,
            // burns the users' crToken balance, not the payout amount,
            // since rest of the payout will be minted as a new generation token
            claimableBalance
        );

        IERC20(shield).transfer(_user, claimed);

        // Amount of new generation cr token to be minted
        newGenerationCRAmount = claimableBalance - claimable;
    }
}
