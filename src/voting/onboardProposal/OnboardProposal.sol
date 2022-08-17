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

pragma solidity ^0.8.13;

import "../../util/OwnableWithoutContext.sol";

import "./OnboardProposalParameters.sol";
import "./OnboardProposalDependencies.sol";
import "./OnboardProposalEventError.sol";

import "../../interfaces/ExternalTokenDependencies.sol";

import "../../interfaces/IDegisToken.sol";
import "../../interfaces/IVeDEG.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Onboard Proposal
 */
contract OnboardProposal is
    OnboardProposalParameters,
    OnboardProposalEventError,
    ExternalTokenDependencies,
    OwnableWithoutContext,
    OnboardProposalDependencies
{
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Total number of reports
    uint256 public proposalCounter;

    struct Proposal {
        string name; // Pool name ("JOE", "GMX")
        address protocolToken; // Protocol native token address
        address proposer; // Proposer address
        uint256 proposeTimestamp; // Timestamp when proposing
        uint256 voteTimestamp; // Timestamp when start voting
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 maxCapacity; // Max capacity ratio
        uint256 basePremiumRatio; // Base annual premium ratio
        uint256 poolId; // Priority pool id
        uint256 status; // Current status (PENDING, VOTING, SETTLED, CLOSED)
        uint256 result; // Final result (PASSED, REJECTED, TIED)
    }
    // Proposal ID => Proposal
    mapping(uint256 => Proposal) public proposals;

    // Protocol token => Whether proposed
    // A protocol can only have one pool
    mapping(address => bool) public poolProposed;

    struct UserVote {
        uint256 choice; // 1: vote for, 2: vote against
        uint256 amount; // veDEG amount for voting
        bool claimed; // Voting reward already claimed
    }
    // User address => report id => user's voting info
    mapping(address => mapping(uint256 => UserVote)) public votes;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor(
        address _deg,
        address _veDeg,
        address _shield
    )
        ExternalTokenDependencies(_deg, _veDeg, _shield)
        OwnableWithoutContext(msg.sender)
    {}

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function getProposal(uint256 _proposalId)
        external
        view
        returns (Proposal memory)
    {
        return proposals[_proposalId];
    }

    function getUserProposalVote(address _user, uint256 _proposalId)
        external
        view
        returns (uint256)
    {
        return votes[_user][_proposalId].choice;
    }

    function getAllProposals()
        external
        view
        returns (Proposal[] memory allProposals)
    {
        uint256 totalProposal = proposalCounter;

        allProposals = new Proposal[](totalProposal);

        for (uint256 i; i < totalProposal; ) {
            allProposals[i] = proposals[i];

            unchecked {
                ++i;
            }
        }
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        onlyOwner
    {
        _setPriorityPoolFactory(_priorityPoolFactory);
    }

    function setProposalCenter(address _proposalCenter) external onlyOwner {
        _setProposalCenter(_proposalCenter);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Start a new proposal
     *
     * @param _name             New project name
     * @param _token            Native token address
     * @param _maxCapacity      Max capacity ratio for the project pool
     * @param _basePremiumRatio Base annual ratio of the premium
     */
    function propose(
        string calldata _name,
        address _token,
        uint256 _maxCapacity,
        uint256 _basePremiumRatio // 10000 == 100% premium annual cost
    ) external {
        require(
            !IPriorityPoolFactory(priorityPoolFactory).tokenRegistered(_token),
            "Protocol already protected"
        );
        require(
            _maxCapacity > 0 
            && _maxCapacity <= MAX_CAPACITY_RATIO
             ,
            "Wrong capacity"
        );
        require(_basePremiumRatio < 10000, "Wrong premium ratio");
        require(!poolProposed[_token], "Protocol already proposed");

        // Burn degis tokens to start a proposal
        IDegisToken(deg).burnDegis(msg.sender, REPORT_THRESHOLD);

        poolProposed[_token] = true;

        uint256 currentProposalCounter = ++proposalCounter;

        // Record the proposal info
        Proposal storage proposal = proposals[currentProposalCounter];
        proposal.protocolToken = _token;
        proposal.proposer = msg.sender;
        proposal.proposeTimestamp = block.timestamp;
        proposal.status = PENDING_STATUS;
        proposal.maxCapacity = _maxCapacity;
        proposal.basePremiumRatio = _basePremiumRatio;

        emit NewProposal(
            _name,
            _token,
            msg.sender,
            _maxCapacity,
            _basePremiumRatio
        );
    }

    /**
     * @notice Start the voting process
     *         Need the approval of dev team
     *
     * @param _id Proposal id to start voting
     */
    function startVoting(uint256 _id) external onlyOwner {
        Proposal storage proposal = proposals[_id];

        require(proposal.status == PENDING_STATUS, "Not pending status");

        proposal.status = VOTING_STATUS;
        proposal.voteTimestamp = block.timestamp;

        emit VotingStart(_id, block.timestamp);
    }

    /**
     * @notice Close a pending proposal
     *
     * @param _id Proposal id
     */
    function closeProposal(uint256 _id) external onlyOwner {
        Proposal storage proposal = proposals[_id];

        // require current proposal to be settled
        require(proposal.status == PENDING_STATUS, "Not pending status");

        proposal.status = CLOSE_STATUS;

        emit ProposalClosed(_id);
    }

    /**
     * @notice Vote for a proposal
     *
     * @param _id     Proposal id
     * @param _isFor  Voting choice
     * @param _amount Amount of veDEG to vote
     */
    function vote(
        uint256 _id,
        uint256 _isFor,
        uint256 _amount
    ) external {
        Proposal storage proposal = proposals[_id];

        // Should be manually switched on the voting process
        require(proposal.status == VOTING_STATUS, "Not voting status");
        require(_isFor == 1 || _isFor == 2, "Wrong choice");
        require(
            !_passedVotingPeriod(proposal.voteTimestamp),
            "Passed voting period"
        );

        _enoughVeDEG(msg.sender, _amount);

        // Lock vedeg until this report is settled
        IVeDEG(veDeg).lockVeDEG(msg.sender, _amount);

        // Record the user's choice
        UserVote storage userVote = votes[msg.sender][_id];
        if (userVote.amount > 0) {
            require(userVote.choice == _isFor, "Can not choose both sides");
        } else {
            userVote.choice = _isFor;
        }
        userVote.amount += _amount;

        // Record the vote for this report
        if (_isFor == 1) {
            proposal.numFor += _amount;
        } else {
            proposal.numAgainst += _amount;
        }

        emit ProposalVoted(_id, msg.sender, _isFor, _amount);
    }

    /**
     * @notice Settle the proposal result
     *
     * @param _id Proposal id
     */
    function settle(uint256 _id) external {
        Proposal storage proposal = proposals[_id];

        require(proposal.status == VOTING_STATUS, "Not voting status");
        require(
            _passedVotingPeriod(proposal.voteTimestamp),
            "Not reached settlement"
        );
        require(proposal.result == 0, "Already settled");

        // If reached quorum, settle the result
        if (_checkQuorum(proposal.numFor + proposal.numAgainst)) {
            uint256 res = _getVotingResult(
                proposal.numFor,
                proposal.numAgainst
            );

            proposal.result = res;
            proposal.status = SETTLED_STATUS;

            // allow for new proposals to be proposed for this protocol
            poolProposed[proposal.protocolToken] = false;

            emit ProposalSettled(_id, res);
        }
        // Else, set the result as "FAILED"
        else {
            proposal.result = FAILED_RESULT;
            proposal.status = SETTLED_STATUS;

            poolProposed[proposal.protocolToken] = false;

            emit ProposalFailed(_id);
        }
    }

    /**
     * @notice Claim back veDEG after voting result settled
     *
     * @param _id Proposal id
     */
    function claim(uint256 _id) external {
        Proposal storage proposal = proposals[_id];

        require(proposal.status == SETTLED_STATUS, "Not settled status");

        UserVote storage userVote = votes[msg.sender][_id];
        // Unlock the veDEG used for voting
        // No reward / punishment
        IVeDEG(veDeg).unlockVeDEG(msg.sender, userVote.amount);

        userVote.claimed = true;

        emit Claimed(_id, msg.sender, userVote.amount);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the final voting result
     *
     * @param _numFor     Votes for
     * @param _numAgainst Votes against
     *
     * @return result Pass, reject or tied
     */
    function _getVotingResult(uint256 _numFor, uint256 _numAgainst)
        internal
        pure
        returns (uint256 result)
    {
        if (_numFor > _numAgainst) result = PASS_RESULT;
        else if (_numFor < _numAgainst) result = REJECT_RESULT;
        else result = TIED_RESULT;
    }

    /**
     * @notice Check whether has passed the voting time period
     *
     * @param _voteTimestamp Start timestamp of the voting
     *
     * @return hasPassed True for passing
     */
    function _passedVotingPeriod(uint256 _voteTimestamp)
        internal
        view
        returns (bool)
    {
        uint256 endTime = _voteTimestamp + VOTING_PERIOD;
        return block.timestamp > endTime;
    }

    /**
     * @notice Check quorum requirement
     *         30% of totalSupply is the minimum requirement for participation
     *
     * @param _totalVotes Total vote numbers
     */
    function _checkQuorum(uint256 _totalVotes) internal view returns (bool) {
        return
            _totalVotes >= (IVeDEG(veDeg).totalSupply() * QUORUM_RATIO) / 100;
    }

    /**
     * @notice Check veDEG to be enough
     *         Only unlocked veDEG will be counted
     *
     * @param _user   User address
     * @param _amount Amount to fulfill
     */
    function _enoughVeDEG(address _user, uint256 _amount) internal view {
        uint256 unlockedBalance = IERC20(veDeg).balanceOf(_user) -
            IVeDEG(veDeg).locked(_user);
        require(unlockedBalance >= _amount, "Not enough veDEG");
    }
}
