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

import "@openzeppelin/contracts/security/Pausable.sol";

import "../util/ProtocolProtection.sol";
import "./ProposalCenterErrors.sol";

import "../interfaces/IVeDEG.sol";

pragma solidity ^0.8.13;

/**
 * @title Proposal Center
 *
 * @author Eric Lee (ylikp.ust@gmail.com) & Primata (primata@375labs.org)
 *
 * @notice This is the Proposal Center where users can submit reports and proposals.
 *         Each proposal and report is assigned a unique ID and is stored in the proposal center.
 *         Users can evaluate proposals and reports and vote to pass them on weighted by their veDeg balance.
 */
contract ProposalCenter is Pausable, ProtocolProtection, ProposalCenterErrors {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public reportCounter;

    struct Report {
        uint256 poolId;
        uint256 timestamp;
        address reporterAddress;
        uint256 yes;
        uint256 no;
        uint256 round;
        bool pending;
        bool approved;
        address[] voted;
    }
    mapping(uint256 => Report) public reports;

    // reportId => address => vote
    mapping(uint256 => mapping(address => bool)) public confirmsReport;

    // refer to pool addresses through policy center
    mapping(address => bool) public poolReported;

    uint256 public reportBuffer;

    struct PoolProposal {
        string protocolName;
        address protocolAddress;
        address proposerAddress;
        address[] voted;
        uint256 maxCapacity;
        // per year in bps 10000 == 100%
        uint256 policyPricePerShield;
        uint256 timestamp;
        uint256 yes;
        uint256 no;
        uint256 round;
        bool pending;
        bool approved;
    }
    uint256 public proposalCounter;

    mapping(uint256 => PoolProposal) public proposals;
    // refer to pool addresses through policy center
    mapping(address => bool) public poolProposed;
    uint256 public proposalBuffer;

    struct UserVote {
        bool choice;
        uint256 amount;
    }
    // User address => report id => user's voting info
    mapping(address => mapping(uint256 => UserVote)) public userReportVotes;
    mapping(address => mapping(uint256 => UserVote)) public userProposalVotes;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event ReportVoted(
        uint256 indexed _reportId,
        address indexed _user,
        bool _vote,
        uint256 _amount
    );
    event ProposalVoted(
        uint256 indexed _proposalId,
        address indexed _user,
        bool _vote,
        uint256 _amount
    );
    event ReportCreated(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress
    );
    event ReportApproved(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress,
        uint256 yes,
        uint256 no
    );
    event ReportRejected(
        uint256 _reportId,
        uint256 _poolId,
        uint256 _timestamp,
        address _reporterAddress,
        uint256 yes,
        uint256 no
    );

    event PoolProposalCreated(
        uint256 indexed _proposalId,
        address _protocol,
        uint256 _maxCapacity,
        uint256 _timestamp,
        address _proposerAddress
    );
    event PoolProposalApproved(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        address _proposerAddress,
        uint256 yes,
        uint256 no
    );
    event PoolProposalRejected(
        uint256 _proposalId,
        address _protocol,
        uint256 _timestamp,
        address _proposerAddress,
        uint256 yes,
        uint256 no
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor() {
        // initiates buffers to 3 days
        reportBuffer = 3 days;
        proposalBuffer = 3 days;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    modifier onlyOwnerOrExecutor() {
        require(
            (msg.sender == owner()) || (msg.sender == executor),
            "Only owner or executor can call this function"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    /**
     * @notice Returns the number of reports in the proposal center.
     * @return poolId           id of the pool the report refers to
     * @return timestamp        timestamp of the report
     * @return reporterAddress  address of the reporter
     * @return yes              number of yes votes in veDEG
     * @return no               number of no votes in veDEG
     * @return pending          if decision is still pending
     * @return approved         if current decision is approved
     * @return voted            list of addresses that have already voted
     */
    function getReport(uint256 _reportId)
        public
        view
        returns (
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            bool,
            bool,
            address[] memory
        )
    {
        Report memory report = reports[_reportId];
        return (
            report.poolId,
            report.timestamp,
            report.reporterAddress,
            report.yes,
            report.no,
            report.pending,
            report.approved,
            report.voted
        );
    }

    /**
     * @notice Returns the number of proposals in the proposal center.
     * @return protocolName     name of the protocol
     * @return protocolAddress  address of the protocol
     * @return proposerAddress  address of the proposer
     * @return voted            list of addresses that have already voted
     * @return maxCapacity      maximum capacity of the pool
     * @return timestamp        timestamp of the proposal
     * @return policyPricePerShield  price per shield in bps
     * @return yes              number of yes votes in veDEG
     * @return no               number of no votes in veDEG
     * @return pending          if decision is still pending
     * @return approved         if current decision is approved

     */
    function getPoolProposal(uint256 _proposalId)
        public
        view
        returns (
            string memory,
            address,
            address,
            address[] memory,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            bool
        )
    {
        PoolProposal memory proposal = proposals[_proposalId];
        return (
            proposal.protocolName,
            proposal.protocolAddress,
            proposal.proposerAddress,
            proposal.voted,
            proposal.maxCapacity,
            proposal.timestamp,
            proposal.policyPricePerShield,
            proposal.yes,
            proposal.no,
            proposal.pending,
            proposal.approved
        );
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Set a pool's state to proposed
     *         If a pool's state is proposed, it can not be proposed again
    
     * @param _poolAddress Address of the pool to be proposed
     * @param _decision    True if reported, false if not proposed
     */
    function setPoolProposed(address _poolAddress, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        poolProposed[_poolAddress] = _decision;
    }

    /**
     * @notice Set a pool's state to reported
     *         If reported, prevents further reporting.
     *
     * @param _poolAddress Address of the pool to be reported
     * @param _decision    True if reported, false if not reported
     */
    function setPoolReported(address _poolAddress, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        poolReported[_poolAddress] = _decision;
    }

    /**
    @notice approves a proposal or not.
    @param _proposalId address of the pool to be proposed
    @param _decision    true if proposed, false if not proposed
     */
    function setProposalApproval(uint256 _proposalId, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        proposals[_proposalId].approved = _decision;
        proposals[_proposalId].pending = false;
    }

    /**
    @notice approves a proposal or not.
    @param _reportId address of the pool to be proposed
    @param _decision    true if proposed, false if not proposed
     */
    function setReportApproval(uint256 _reportId, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        reports[_reportId].approved = _decision;
        reports[_reportId].pending = false;
    }

    /**
    @notice sets report and proposal voting buffers.
    @param _reportBuffer buffer for reports
    @param _proposalBuffer buffer for proposals
    */
    function setBuffers(uint256 _reportBuffer, uint256 _proposalBuffer)
        external
        onlyOwnerOrExecutor
    {
        reportBuffer = _reportBuffer;
        proposalBuffer = _proposalBuffer;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Vote on currently pending report in proposal center.
     *         Voting power is decided by the amount of staked veDEG.
     *         Rewarded if votes with majority.
     *         Punished if votes against majority.
     *
     * @param _reportId Id of the report to be voted on
     * @param _vote     The user's choice
     * @param _amount   Amount of veDEG used for this vote
     */
    function voteReport(
        uint256 _reportId,
        bool _vote,
        uint256 _amount
    ) external {
        require(reports[_reportId].pending, "Report is not pending");

        // Should have enough veDEG
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        if (balance < _amount) revert NotEnoughVeDEG();

        // Lock vedeg until this report is settled
        IVeDEG(veDeg).lockVeDEG(msg.sender, _amount);

        // Record the user's choice
        UserVote storage userReportVote = userReportVotes[msg.sender][
            _reportId
        ];
        if (userReportVote.amount > 0) {
            require(
                userReportVote.choice == _vote,
                "Can not choose both sides"
            );
        } else {
            userReportVote.choice = _vote;
        }

        // Record the vote for this report
        if (_vote) {
            reports[_reportId].yes += balance;
        } else {
            reports[_reportId].no += balance;
        }

        emit ReportVoted(_reportId, msg.sender, _vote, _amount);
    }

    /**
    @notice votes on currently pending proposal in proposal center.
            voting power is decided by the amount of staked veDEG.
            no penalty nor rewards.
    @param _proposalId id of the pool proposal to be voted on
    @param _vote true if yes, false if no
    */
    function votePoolProposal(uint256 _proposalId, bool _vote) external {
        require(proposals[_proposalId].pending, "Report is not pending");
        address[] storage voted = proposals[_proposalId].voted;
        uint256 length = voted.length;
        // verifies if address already voted
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "Address already voted");
        }
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // register votes
        if (_vote) {
            proposals[_proposalId].yes += balance;
        } else {
            proposals[_proposalId].no += balance;
        }
        // registers voter
        voted.push(msg.sender);
        emit Vote(_proposalId, _vote, "New Pool");
    }

    /**
    @notice evaluates votes on a pending report in proposal center.
            if it approval is the same twice in a row or round is 2,
            it is approved and sent to executor queue.
    @param _reportId id of the report to be voted on
    */
    function evaluateReportVotes(uint256 _reportId) external {
        require(reports[_reportId].pending, "report not pending");
        // 3 days for the report to be evaluated
        require(
            reports[_reportId].timestamp + reportBuffer < block.timestamp,
            "report not ready"
        );

        uint256 total = reports[_reportId].yes + reports[_reportId].no;
        // requires 30% of vedeg total supply to vote on a report
        require(
            total > (IERC20(veDeg).totalSupply() * 3) / 10,
            "Not enough votes"
        );
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            reports[_reportId].poolId
        );
        bool result = reports[_reportId].yes > reports[_reportId].no;
        // if last round or vote agrees with previous round, move on with the report
        if (
            (reports[_reportId].round == 2) ||
            (reports[_reportId].round > 0 &&
                result == reports[_reportId].approved)
        ) {
            if (result) {
                reports[_reportId].approved = true;
                emit ReportApproved(
                    _reportId,
                    reports[_reportId].poolId,
                    reports[_reportId].timestamp,
                    reports[_reportId].reporterAddress,
                    reports[_reportId].yes,
                    reports[_reportId].no
                );
                // queue report for execution
                IExecutor(executor).queueReport(
                    reports[_reportId].pending,
                    reports[_reportId].approved,
                    _reportId,
                    reports[_reportId].poolId
                );
            } else {
                // pool is not approved and pool is open to new proposal
                reports[_reportId].approved = false;
                poolReported[pool] = false;
                emit ReportRejected(
                    _reportId,
                    reports[_reportId].poolId,
                    reports[_reportId].timestamp,
                    reports[_reportId].reporterAddress,
                    reports[_reportId].yes,
                    reports[_reportId].no
                );
            }
            reports[_reportId].pending = false;
        } else {
            // if not definitive round, set approval for future check
            // and add 24hrs to voting period
            reports[_reportId].approved = result;
            reports[_reportId].timestamp += 86400;
        }
        reports[_reportId].round++;
    }

    /**
    @notice evaluates votes on a pending pool proposal in proposal center.
            if it approval is the same twice in a row or round is 2,
            it is approved and sent to executor queue.
    @param _proposalId id of the proposal to be voted on
    */
    function evaluatePoolProposalVotes(uint256 _proposalId) external {
        require(proposals[_proposalId].pending, "proposal not pending");
        // 3 days for the report to be evaluated
        require(
            proposals[_proposalId].timestamp + proposalBuffer <
                block.timestamp,
            "proposal not ready"
        );
        address protocol = proposals[_proposalId].protocolAddress;
        uint256 total = proposals[_proposalId].yes +
            proposals[_proposalId].no;
        // requires 30% of vedeg total supply to vote on a proposal
        require(
            total > (IERC20(veDeg).totalSupply() * 3) / 10,
            "Not enough votes"
        );
        bool result = proposals[_proposalId].yes >
            proposals[_proposalId].no;
        // if last round or vote agrees with previous round, move on with the report
        if (
            (proposals[_proposalId].round == 2) ||
            (proposals[_proposalId].round > 0 &&
                result == proposals[_proposalId].approved)
        ) {
            if (result) {
                proposals[_proposalId].approved = true;
                emit PoolProposalApproved(
                    _proposalId,
                    protocol,
                    proposals[_proposalId].timestamp,
                    proposals[_proposalId].proposerAddress,
                    proposals[_proposalId].yes,
                    proposals[_proposalId].no
                );
                // queue pool for execution
                IExecutor(executor).queuePool(
                    proposals[_proposalId].protocolName,
                    _proposalId,
                    proposals[_proposalId].protocolAddress,
                    proposals[_proposalId].maxCapacity,
                    proposals[_proposalId].policyPricePerShield,
                    proposals[_proposalId].pending,
                    proposals[_proposalId].approved
                );
            } else {
                // pool is not approved and pool is open to new proposal
                proposals[_proposalId].approved = false;
                poolProposed[protocol] = false;
                emit PoolProposalRejected(
                    _proposalId,
                    protocol,
                    proposals[_proposalId].timestamp,
                    proposals[_proposalId].proposerAddress,
                    proposals[_proposalId].yes,
                    proposals[_proposalId].no
                );
            }
            proposals[_proposalId].pending = false;
        } else {
            // if not definitive round, set approval for future check
            // and add 24hrs to voting period
            proposals[_proposalId].approved = result;
            proposals[_proposalId].timestamp += 86400;
        }
        proposals[_proposalId].round++;
    }

    /**
    @notice reports that a protocol has been compromised.
            user notifies that pool should be liquidated.
            1000 DEG tokens are held by the proposal center
            until report is deemed truthful.
    @param _poolId id of the pool to be reported
    */
    function reportPool(uint256 _poolId) public {
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            _poolId
        );
        require(!poolReported[pool], "Pool already reported");
        require(pool != address(0), "Pool doesn't exist");
        ++reportCounter;
        address[] memory initializeArray;
        poolReported[pool] = true;
        // registers new report
        reports[reportCounter] = Report(
            _poolId,
            block.timestamp,
            msg.sender,
            0,
            0,
            0,
            true,
            false,
            initializeArray
        );
        // transfer back to deg address. another option is to burn it.
        IERC20(deg).transferFrom(msg.sender, deg, 1000);
        IInsurancePool(pool).setPausedInsurancePool(true);
        IReinsurancePool(reinsurancePool).setPausedReinsurancePool(true);

        emit ReportCreated(
            reportCounter,
            reports[reportCounter].poolId,
            reports[reportCounter].timestamp,
            reports[reportCounter].reporterAddress
        );
    }

    /**
    @notice proposes a new protocol to be insured.

    @param _protocol            address of token to receive have a new insurance pool.
    @param _name                name of the protocol to be insured.
    @param _maxCapacity         maximum capacity of the insurance pool in native token.
    @param _policyPricePerToken price of the policy in native token.
    */
    function proposePool(
        address _protocol,
        string memory _name,
        uint256 _maxCapacity,
        uint256 _policyPricePerToken
    ) public {
        require(!poolProposed[_protocol], "Protocol already proposed");
        ++proposalCounter;
        address[] memory emptyVoted;
        // registers new proposal
        proposals[proposalCounter] = PoolProposal(
            _name,
            _protocol,
            msg.sender,
            emptyVoted,
            _maxCapacity,
            _policyPricePerToken,
            block.timestamp,
            0,
            0,
            0,
            true,
            false
        );

        // sets protocol to proposed so there are no cuncurrent duplicates
        poolProposed[_protocol] = true;
        emit PoolProposalCreated(
            proposalCounter,
            _protocol,
            proposals[proposalCounter].maxCapacity,
            proposals[proposalCounter].timestamp,
            proposals[proposalCounter].proposerAddress
        );
    }

    /**
    @notice reward voters for a report with a final result and penalizes
            bad votes.
            Only callable through executor.
    @param _reportId    id of the report to be reward voters on.
    @param _veredict    true if report was approved, false if rejected.
     */
    function rewardByReportId(uint256 _reportId, bool _veredict) external {
        require(msg.sender == executor, "Only Executor can liquidate");
        address[] memory voted = reports[_reportId].voted;
        uint256 reward = 0;
        if (_veredict) {
            IPolicyCenter(policyCenter).rewardTreasuryToReporter(
                reports[_reportId].reporterAddress
            );
            MockDEG(deg).mintDegis(reports[_reportId].reporterAddress, 2000);
            // punishment for voting against majority
            for (uint256 i = 0; i < voted.length; i++) {
                if (confirmsReport[_reportId][voted[i]] != _veredict) {
                    (uint256 veDegBalance, ) = MockVeDEG(deg).users(
                        1,
                        voted[i]
                    );
                    uint256 stakedDegPenalty = (veDegBalance * 4) / 500;
                    reward += stakedDegPenalty;
                    MockDEG(deg).transferFrom(
                        voted[i],
                        address(this),
                        stakedDegPenalty
                    );
                    // unlock vedeg balance
                    MockVeDEG(veDeg).unlockVeDEG(
                        voted[i],
                        (veDegBalance * 4) / 5
                    );
                }
            }
            // rewards for voting with majority
            for (uint256 i = 0; i < voted.length; i++) {
                if (confirmsReport[_reportId][voted[i]] == _veredict) {
                    // if voted with the decision, reward 50% of penalty to voters
                    // according to the amount of vedeg they hold
                    uint256 balance = IERC20(veDeg).balanceOf(voted[i]);
                    uint256 toTransfer = (balance * reports[_reportId].yes) / 2;
                    MockDEG(deg).transfer(voted[i], toTransfer);
                    MockVeDEG(veDeg).unlockVeDEG(voted[i], (balance * 4) / 5);
                    reward -= toTransfer;
                }
            }
            MockDEG(deg).transfer(policyCenter, reward);
        }
    }
}
