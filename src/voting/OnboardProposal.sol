// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../util/ProtocolProtection.sol";

import "./interfaces/OnboardProposalParameters.sol";

contract OnboardProposal is ProtocolProtection, OnboardProposalParameters {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Total number of reports
    uint256 public proposalCounter;

    struct Proposal {
        string name;
        address protocolToken;
        address proposer;
        uint256 proposeTimestamp;
        uint256 numFor; // Votes voting for
        uint256 numAgainst; // Votes voting against
        uint256 maxCapacity;
        uint256 priceRatio;
        uint256 poolId;
        uint256 status;
        uint256 result;
    }
    // Proposal ID => Proposal
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public poolProposed;

    struct UserVote {
        uint256 choice; // 1: vote for, 2: vote against
        uint256 amount;
        bool claimed;
    }
    // User address => report id => user's voting info
    mapping(address => mapping(uint256 => UserVote)) public userProposalVotes;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event NewProposal(
        string name,
        address token,
        uint256 maxCapacity,
        uint256 priceRatio
    );

    event ProposalVoted(
        uint256 proposalId,
        address indexed user,
        uint256 voteFor,
        uint256 amount
    );

    event ProposalSettled(uint256 proposalId, uint256 result);

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function getProposal(uint256 _proposalId)
        public
        view
        returns (Proposal memory)
    {
        return proposals[_proposalId];
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Start a new proposal
     *
     * @param _name        New project name
     * @param _token       Native token address
     * @param _maxCapacity Max capacity for the project pool
     * @param _priceRatio  Price ratio of the premium
     */
    function propose(
        string calldata _name,
        address _token,
        uint256 _maxCapacity,
        uint256 _priceRatio // 10000 == 100% premium anual cost
    ) external {
        require(
            !IInsurancePoolFactory(insurancePoolFactory).tokenRegistered(
                _token
            ),
            "Protocol already protected"
        );

        require(poolProposed[_token] == false, "Protocol already proposed");

        // Burn degis tokens to start a proposal
        IDegisToken(deg).burnDegis(msg.sender, REPORT_THRESHOLD);

        poolProposed[_token] = true;

        uint256 currentProposalCounter = ++proposalCounter;

        Proposal storage proposal = proposals[currentProposalCounter];
        proposal.protocolToken = _token;
        proposal.proposer = msg.sender;
        proposal.proposeTimestamp = block.timestamp;
        proposal.status = PENDING_STATUS;
        proposal.maxCapacity = _maxCapacity;
        proposal.priceRatio = _priceRatio;

        emit NewProposal(_name, _token, _maxCapacity, _priceRatio);
    }

    /**
     * @notice Start a new proposal from proposal center
     *
     * @param _name        New project name
     * @param _token       Native token address
     * @param _maxCapacity Max capacity for the project pool
     * @param _priceRatio  Price ratio of the premium
     */
    function propose(
        string calldata _name,
        address _token,
        uint256 _maxCapacity,
        uint256 _priceRatio, // 10000 == 100% premium anual cost
        address _msgsender
    ) external {
        require(msg.sender == proposalCenter, "not sent from proposal center");

        require(
            !IInsurancePoolFactory(insurancePoolFactory).tokenRegistered(
                _token
            ),
            "Protocol already protected"
        );

        require(poolProposed[_token] == false, "Protocol already proposed");

        // Burn degis tokens to start a proposal
        IDegisToken(deg).burnDegis(_msgsender, REPORT_THRESHOLD);

        poolProposed[_token] = true;

        uint256 currentProposalCounter = ++proposalCounter;

        Proposal storage proposal = proposals[currentProposalCounter];
        proposal.protocolToken = _token;
        proposal.proposer = _msgsender;
        proposal.proposeTimestamp = block.timestamp;
        proposal.status = PENDING_STATUS;
        proposal.maxCapacity = _maxCapacity;
        proposal.priceRatio = _priceRatio;

        emit NewProposal(_name, _token, _maxCapacity, _priceRatio);
    }

    /**
     * @notice Vote for a proposal
     *
     * @param _proposalId Proposal id
     * @param _isFor      Voting choice
     * @param _amount     Amount to vote
     */
    function vote(
        uint256 _proposalId,
        uint256 _isFor,
        uint256 _amount
    ) external {
        // Should be manually switched on the voting process
        require(
            proposals[_proposalId].status == VOTING_STATUS,
            "Not voting status"
        );

        require(_isFor == 1 || _isFor == 2, "Wrong choice");

        _enoughVeDEG(msg.sender, _amount);

        // Lock vedeg until this report is settled
        IVeDEG(veDeg).lockVeDEG(msg.sender, _amount);

        // Record the user's choice
        UserVote storage userProposalVote = userProposalVotes[msg.sender][
            _proposalId
        ];
        if (userProposalVote.amount > 0) {
            require(
                userProposalVote.choice == _isFor,
                "Can not choose both sides"
            );
        } else {
            userProposalVote.choice = _isFor;
        }

        Proposal storage currentProposal = proposals[_proposalId];
        // Record the vote for this report
        if (_isFor == 1) {
            currentProposal.numFor += _amount;
        } else {
            currentProposal.numAgainst += _amount;
        }

        emit ProposalVoted(_proposalId, msg.sender, _isFor, _amount);
    }

    /**
     * @notice Vote for a proposal
     *
     * @param _proposalId Proposal id
     * @param _isFor      Voting choice
     * @param _amount     Amount to vote
     */
    function vote(
        uint256 _proposalId,
        uint256 _isFor,
        uint256 _amount,
        address _msgsender
    ) external {
        require(msg.sender == proposalCenter, "not sent from proposal center");
        // Should be manually switched on the voting process
        require(
            proposals[_proposalId].status == VOTING_STATUS,
            "Not voting status"
        );

        require(_isFor == 1 || _isFor == 2, "Wrong choice");

        _enoughVeDEG(_msgsender, _amount);

        // Lock vedeg until this report is settled
        IVeDEG(veDeg).lockVeDEG(_msgsender, _amount);

        // Record the user's choice
        UserVote storage userProposalVote = userProposalVotes[_msgsender][
            _proposalId
        ];
        if (userProposalVote.amount > 0) {
            require(
                userProposalVote.choice == _isFor,
                "Can not choose both sides"
            );
        } else {
            userProposalVote.choice = _isFor;
        }

        Proposal storage currentProposal = proposals[_proposalId];
        // Record the vote for this report
        if (_isFor == 1) {
            currentProposal.numFor += _amount;
        } else {
            currentProposal.numAgainst += _amount;
        }

        emit ProposalVoted(_proposalId, _msgsender, _isFor, _amount);
    }

    /**
     * @notice Settle the proposal
     *
     * @param _proposalId Proposal id
     */
    function settle(uint256 _proposalId) external {
        Proposal storage currentProposal = proposals[_proposalId];

        require(currentProposal.status == VOTING_STATUS, "Not voting status");

        // Check has passed the voting period
        require(
            _passedVotingPeriod(currentProposal.proposeTimestamp),
            "Not reached settlement"
        );

        require(currentProposal.result == 0, "Already settled");

        _checkQuorum(currentProposal.numFor + currentProposal.numAgainst);

        uint256 res = _getVotingResult(
            currentProposal.numFor,
            currentProposal.numAgainst
        );

        currentProposal.result = res;
        currentProposal.status = SETTLED_STATUS;

        // allow for new proposals to be proposed for this protocol
        poolProposed[currentProposal.protocolToken] = false;
        emit ProposalSettled(_proposalId, res);
    }

    function closeProposal(uint256 _proposalId) external onlyOwner {

        Proposal storage currentProposal = proposals[_proposalId];

        // require current proposal to be settled
        require(
            currentProposal.status == PENDING_STATUS,
            "Not pending or settled status"
        );

        // Must close the report before pending period ends
        require(
            !_passedVotingPeriod(currentProposal.proposeTimestamp),
            "Already passed pending period"
        );

        currentProposal.status = CLOSE_STATUS;
    }

    /**
     * @notice Claim back veDEG after voting result settled
     *
     * @param _proposalId Proposal id
     */
    function claim(uint256 _proposalId) external {
        Proposal storage currentProposal = proposals[_proposalId];

        require(currentProposal.status == SETTLED_STATUS, "Not settled status");

        UserVote storage userVote = userProposalVotes[msg.sender][_proposalId];

        IVeDEG(veDeg).unlockVeDEG(msg.sender, userVote.amount);

        userVote.claimed = true;
    }

    /**
     * @notice Claim back veDEG after voting result settled
     *
     * @param _proposalId Proposal id
     */
    function claim(uint256 _proposalId, address _msgsender) external {
        require(msg.sender == proposalCenter, "Only proposal center can claim");
        Proposal storage currentProposal = proposals[_proposalId];

        require(currentProposal.status == SETTLED_STATUS, "Not settled status");

        UserVote storage userVote = userProposalVotes[_msgsender][_proposalId];

        IVeDEG(veDeg).unlockVeDEG(_msgsender, userVote.amount);

        userVote.claimed = true;
    }

    

    /**
     * @notice Check if the proposal is settled
     *
     * @param _proposalId Proposal id
     */
    function startVoting(uint256 _proposalId) external {
        Proposal storage currentProposal = proposals[_proposalId];

        require(currentProposal.status == PENDING_STATUS, "Not pending status");

        require(
            _passedVotingPeriod(currentProposal.proposeTimestamp),
            "Not reached voting period"
        );

        currentProposal.status = VOTING_STATUS;
    }

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
     * @param _reportTime Start timestamp of the report
     *
     * @return hasPassed True for passing
     */
    function _passedVotingPeriod(uint256 _reportTime)
        internal
        view
        returns (bool)
    {
        uint256 endTime = _reportTime + VOTING_PERIOD;

        return block.timestamp > endTime;
    }

    /**
     * @notice Check quorum requirement
     *         30% of totalSupply is the minimum requirement for participation
     *
     * @param _totalVotes Total vote numbers
     */
    function _checkQuorum(uint256 _totalVotes) internal view {
        require(
            _totalVotes >= (IVeDEG(veDeg).totalSupply() * QUORUM_RATIO) / 100,
            "Not reached quorum"
        );
    }

    /**
     * @notice Check veDEG to be enough
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
