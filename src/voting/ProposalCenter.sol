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

import "../util/ProtocolProtection.sol";

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
contract ProposalCenter is ProtocolProtection {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

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

    uint256 public reportCounter;
    mapping(uint256 => Report) public reportIds;
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
    mapping(uint256 => PoolProposal) public proposalIds;
    // refer to pool addresses through policy center
    mapping(address => bool) public poolProposed;
    uint256 public proposalBuffer;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Vote(uint256 _id, bool _quorum, string _who);
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
        Report memory report = reportIds[_reportId];
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
        PoolProposal memory proposal = proposalIds[_proposalId];
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

    /**
    @notice sets a pool state to reported. If reported, prevents further proposed.
    @param _poolAddress address of the pool to be proposed
    @param _decision    true if reported, false if not proposed
     */
    function setPoolProposed(address _poolAddress, bool _decision)
        external
        onlyOwnerOrExecutor
    {
        poolProposed[_poolAddress] = _decision;
    }

    /**
    @notice sets a pool state to reported. If reported, prevents further reporting.
    @param _poolAddress address of the pool to be reported
    @param _decision    true if reported, false if not reported
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
        proposalIds[_proposalId].approved = _decision;
        proposalIds[_proposalId].pending = false;
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
        reportIds[_reportId].approved = _decision;
        reportIds[_reportId].pending = false;
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
    @notice votes on currently pending report in proposal center.
            voting power is decided by the amount of staked veDEG.
            rewarded if votes with majority.
            punished if votes against majority.
    @param _reportId id of the report to be voted on
    @param _vote true if yes, false if no
    */
    function voteReport(uint256 _reportId, bool _vote) external {
        require(reportIds[_reportId].pending, "Report is not pending");
        address[] storage voted = reportIds[_reportId].voted;
        uint256 length = voted.length;
        // verifies if address already voted
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "Address already voted");
        }
        // vedeg weight to vote in balance
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // lock vedeg until vote is processed
        IVeDEG(veDeg).lockVeDEG(msg.sender, (balance * 4) / 5);
        // register vote
        if (_vote) {
            reportIds[_reportId].yes += balance;
            confirmsReport[_reportId][msg.sender] = true;
        } else {
            reportIds[_reportId].no += balance;
            confirmsReport[_reportId][msg.sender] = false;
        }
        // registers voter
        voted.push(msg.sender);
        emit Vote(_reportId, _vote, "Report");
    }

    /**
    @notice votes on currently pending proposal in proposal center.
            voting power is decided by the amount of staked veDEG.
            no penalty nor rewards.
    @param _proposalId id of the pool proposal to be voted on
    @param _vote true if yes, false if no
    */
    function votePoolProposal(uint256 _proposalId, bool _vote) external {
        require(proposalIds[_proposalId].pending, "Report is not pending");
        address[] storage voted = proposalIds[_proposalId].voted;
        uint256 length = voted.length;
        // verifies if address already voted
        for (uint256 i = 0; i < length; i++) {
            require(voted[i] != msg.sender, "Address already voted");
        }
        uint256 balance = IERC20(veDeg).balanceOf(msg.sender);
        require(balance > 0, "You have no tokens");
        // register votes
        if (_vote) {
            proposalIds[_proposalId].yes += balance;
        } else {
            proposalIds[_proposalId].no += balance;
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
        require(reportIds[_reportId].pending, "report not pending");
        // 3 days for the report to be evaluated
        require(
            reportIds[_reportId].timestamp + reportBuffer < block.timestamp,
            "report not ready"
        );

        uint256 total = reportIds[_reportId].yes + reportIds[_reportId].no;
        // requires 30% of vedeg total supply to vote on a report
        require(
            total > (IERC20(veDeg).totalSupply() * 3) / 10,
            "Not enough votes"
        );
        address pool = IPolicyCenter(policyCenter).getInsurancePoolById(
            reportIds[_reportId].poolId
        );
        bool result = reportIds[_reportId].yes > reportIds[_reportId].no;
        // if last round or vote agrees with previous round, move on with the report
        if (
            (reportIds[_reportId].round == 2) ||
            (reportIds[_reportId].round > 0 &&
                result == reportIds[_reportId].approved)
        ) {
            if (result) {
                reportIds[_reportId].approved = true;
                emit ReportApproved(
                    _reportId,
                    reportIds[_reportId].poolId,
                    reportIds[_reportId].timestamp,
                    reportIds[_reportId].reporterAddress,
                    reportIds[_reportId].yes,
                    reportIds[_reportId].no
                );
                // queue report for execution
                IExecutor(executor).queueReport(
                    reportIds[_reportId].pending,
                    reportIds[_reportId].approved,
                    _reportId,
                    reportIds[_reportId].poolId
                );
            } else {
                // pool is not approved and pool is open to new proposal
                reportIds[_reportId].approved = false;
                poolReported[pool] = false;
                emit ReportRejected(
                    _reportId,
                    reportIds[_reportId].poolId,
                    reportIds[_reportId].timestamp,
                    reportIds[_reportId].reporterAddress,
                    reportIds[_reportId].yes,
                    reportIds[_reportId].no
                );
            }
            reportIds[_reportId].pending = false;
        } else {
            // if not definitive round, set approval for future check
            // and add 24hrs to voting period
            reportIds[_reportId].approved = result;
            reportIds[_reportId].timestamp += 86400;
        }
        reportIds[_reportId].round++;
    }

    /**
    @notice evaluates votes on a pending pool proposal in proposal center.
            if it approval is the same twice in a row or round is 2,
            it is approved and sent to executor queue.
    @param _proposalId id of the proposal to be voted on
    */
    function evaluatePoolProposalVotes(uint256 _proposalId) external {
        require(proposalIds[_proposalId].pending, "proposal not pending");
        // 3 days for the report to be evaluated
        require(
            proposalIds[_proposalId].timestamp + proposalBuffer <
                block.timestamp,
            "proposal not ready"
        );
        address protocol = proposalIds[_proposalId].protocolAddress;
        uint256 total = proposalIds[_proposalId].yes +
            proposalIds[_proposalId].no;
        // requires 30% of vedeg total supply to vote on a proposal
        require(
            total > (IERC20(veDeg).totalSupply() * 3) / 10,
            "Not enough votes"
        );
        bool result = proposalIds[_proposalId].yes >
            proposalIds[_proposalId].no;
        // if last round or vote agrees with previous round, move on with the report
        if (
            (proposalIds[_proposalId].round == 2) ||
            (proposalIds[_proposalId].round > 0 &&
                result == proposalIds[_proposalId].approved)
        ) {
            if (result) {
                proposalIds[_proposalId].approved = true;
                emit PoolProposalApproved(
                    _proposalId,
                    protocol,
                    proposalIds[_proposalId].timestamp,
                    proposalIds[_proposalId].proposerAddress,
                    proposalIds[_proposalId].yes,
                    proposalIds[_proposalId].no
                );
                // queue pool for execution
                IExecutor(executor).queuePool(
                    proposalIds[_proposalId].protocolName,
                    _proposalId,
                    proposalIds[_proposalId].protocolAddress,
                    proposalIds[_proposalId].maxCapacity,
                    proposalIds[_proposalId].policyPricePerShield,
                    proposalIds[_proposalId].pending,
                    proposalIds[_proposalId].approved
                );
            } else {
                // pool is not approved and pool is open to new proposal
                proposalIds[_proposalId].approved = false;
                poolProposed[protocol] = false;
                emit PoolProposalRejected(
                    _proposalId,
                    protocol,
                    proposalIds[_proposalId].timestamp,
                    proposalIds[_proposalId].proposerAddress,
                    proposalIds[_proposalId].yes,
                    proposalIds[_proposalId].no
                );
            }
            proposalIds[_proposalId].pending = false;
        } else {
            // if not definitive round, set approval for future check
            // and add 24hrs to voting period
            proposalIds[_proposalId].approved = result;
            proposalIds[_proposalId].timestamp += 86400;
        }
        proposalIds[_proposalId].round++;
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
        reportIds[reportCounter] = Report(
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
            reportIds[reportCounter].poolId,
            reportIds[reportCounter].timestamp,
            reportIds[reportCounter].reporterAddress
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
        proposalIds[proposalCounter] = PoolProposal(
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
            proposalIds[proposalCounter].maxCapacity,
            proposalIds[proposalCounter].timestamp,
            proposalIds[proposalCounter].proposerAddress
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
        address[] memory voted = reportIds[_reportId].voted;
        uint256 reward = 0;
        if (_veredict) {
            IPolicyCenter(policyCenter).rewardTreasuryToReporter(
                reportIds[_reportId].reporterAddress
            );
            IDegisToken(deg).mintDegis(reportIds[_reportId].reporterAddress, 2000);
            // punishment for voting against majority
            for (uint256 i = 0; i < voted.length; i++) {
                if (confirmsReport[_reportId][voted[i]] != _veredict) {
                    (uint256 veDegBalance, ) = IVeDEG(deg).users(
                        1,
                        voted[i]
                    );
                    uint256 stakedDegPenalty = (veDegBalance * 4) / 500;
                    reward += stakedDegPenalty;
                    IERC20(deg).transferFrom(
                        voted[i],
                        address(this),
                        stakedDegPenalty
                    );
                    // unlock vedeg balance
                    IVeDEG(veDeg).unlockVeDEG(
                        voted[i],
                        (veDegBalance * 4) / 5
                    );
                }
            }
            // rewards for voting with majority
            if (reward > 0){
                for (uint256 i = 0; i < voted.length; i++) {
                if (confirmsReport[_reportId][voted[i]] == _veredict) {
                    // if voted with the decision, reward 50% of penalty to voters
                    // according to the amount of vedeg they hold
                    uint256 balance = IERC20(veDeg).balanceOf(voted[i]);
                    uint256 toTransfer = (balance * reportIds[_reportId].yes) /
                        2;
                    IDegisToken(deg).mintDegis(voted[i], toTransfer);
                    MockVeDEG(veDeg).unlockVeDEG(voted[i], balance * 4000 / 5000);
                    console.log(reward);
                    reward -= toTransfer;
                }
            }
            IERC20(deg).transfer(policyCenter, reward);
            }
        }
    }
}
