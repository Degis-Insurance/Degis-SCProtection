// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../interfaces/ICoverRightTokenFactory.sol";
import "../interfaces/ICoverRightToken.sol";
import "../interfaces/IPriorityPool.sol";
import "../interfaces/IPriorityPoolFactory.sol";

import "./SimpleIERC20.sol";

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
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant SCALE = 1e12;

    uint256 public constant CLAIM_PERIOD = 30 days;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public shield;

    address public crFactory;

    address public policyCenter;

    address public priorityPoolFactory;

    struct Payout {
        uint256 amount;
        uint256 remaining;
        uint256 endTiemstamp;
        uint256 ratio;
        address priorityPool;
    }
    // Pool id => Generation => Payout
    mapping(uint256 => mapping(uint256 => Payout)) public payouts;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event NewPayout(
        uint256 indexed _poolId,
        uint256 _generation,
        uint256 _amount,
        uint256 _ratio
    );

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    error PayoutPool__OnlyPriorityPool();
    error PayoutPool__NotPolicyCenter();
    error PayoutPool__WrongCRToken();
    error PayoutPool__NoPayout();

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _shield,
        address _policyCenter,
        address _crFactory,
        address _priorityPoolFactory
    ) {
        shield = _shield;
        policyCenter = _policyCenter;
        crFactory = _crFactory;
        priorityPoolFactory = _priorityPoolFactory;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyPriorityPool(uint256 _poolId) {
        (, address poolAddress, , , ) = IPriorityPoolFactory(
            priorityPoolFactory
        ).pools(_poolId);
        if (poolAddress != msg.sender) revert PayoutPool__OnlyPriorityPool();
        _;
    }

    modifier onlyPolicyCenter() {
        if (msg.sender != policyCenter) revert PayoutPool__NotPolicyCenter();
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice New payout comes in
     *
     *         Only callable from one of the priority pools
     *
     *         After the pool's report is passed and executed,
     *         part of the assets will be moved to this pool.
     *
     *
     * @param _poolId       Pool Id
     * @param _generation   Generation of priority pool (start at 1)
     * @param _amount       Total amount to be claimed
     * @param _ratio        Payout ratio of this payout (users can only use part of their crTokens to claim)
     * @param _poolAddress  Address of priority pool
     */
    function newPayout(
        uint256 _poolId,
        uint256 _generation,
        uint256 _amount,
        uint256 _ratio,
        address _poolAddress
    ) external onlyPriorityPool(_poolId) {
        Payout storage payout = payouts[_poolId][_generation];

        // Store the information
        payout.amount = _amount;
        payout.endTiemstamp = block.timestamp + CLAIM_PERIOD;
        payout.ratio = _ratio;
        payout.priorityPool = _poolAddress;

        emit NewPayout(_poolId, _generation, _amount, _ratio);
    }

    /**
     * @notice Claim payout for a user
     *
     *         Only callable from policy center
     *         Need provide certain crToken address and generation
     *
     * @param _user       User address
     * @param _crToken    Cover right token address
     * @param _poolId     Pool Id
     * @param _generation Generation of priority pool (started at 1)
     *
     * @return claimed               The actual amount transferred to the user
     * @return newGenerationCRAmount New generation crToken minted to the user
     */
    function claim(
        address _user,
        address _crToken,
        uint256 _poolId,
        uint256 _generation
    )
        external
        onlyPolicyCenter
        returns (uint256 claimed, uint256 newGenerationCRAmount)
    {
        Payout storage payout = payouts[_poolId][_generation];

        uint256 expiry = ICoverRightToken(_crToken).expiry();

        // Check the crToken address and generation matched
        bytes32 salt = keccak256(
            abi.encodePacked(_poolId, expiry, _generation)
        );
        if (ICoverRightTokenFactory(crFactory).saltToAddress(salt) != _crToken)
            revert PayoutPool__WrongCRToken();

        // Get claimable amount of crToken
        uint256 claimableBalance = ICoverRightToken(_crToken).getClaimableOf(
            _user
        );
        // Only part of the crToken can be used for claim
        uint256 claimable = (claimableBalance * payout.ratio) / SCALE;

        if (claimable == 0) revert PayoutPool__NoPayout();

        uint256 coverIndex = IPriorityPool(payout.priorityPool).coverIndex();

        // Actual amount given to the user
        claimed = (claimable * coverIndex) / 10000;

        ICoverRightToken(_crToken).burn(
            _poolId,
            _user,
            // burns the users' crToken balance, not the payout amount,
            // since rest of the payout will be minted as a new generation token
            claimableBalance
        );

        SimpleIERC20(shield).transfer(_user, claimed);

        // Amount of new generation cr token to be minted
        newGenerationCRAmount = claimableBalance - claimable;
    }
}
