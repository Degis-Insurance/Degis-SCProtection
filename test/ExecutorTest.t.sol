// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.13;

// import "./utils/ContractSetupBaseTest.sol";

// import "src/interfaces/IOnboardProposal.sol";
// import "src/interfaces/IPriorityPool.sol";

// import "src/voting/onboardProposal/OnboardProposalParameters.sol";
// import "src/voting/onboardProposal/OnboardProposalEventError.sol";
// import "src/voting/incidentReport/IncidentReportParameters.sol";
// import "src/voting/incidentReport/IncidentReportEventError.sol";
// import "src/core/interfaces/ExecutorEventError.sol";

// import "forge-std/console.sol";

// contract ExecutorTest is
//     ExecutorEventError,
//     ContractSetupBaseTest,
//     OnboardProposalParameters,
//     IncidentReportParameters,
//     OnboardProposalEventError,
//     IncidentReportEventError
// {
//     uint256 internal constant SCALE = 1e12;

//     address internal ALICE = mkaddr("Alice");
//     address internal BOB = mkaddr("Bob");
//     address internal CHARLIE = mkaddr("Charlie");

//     uint256 internal constant CAPACITY_1 = 40;
//     uint256 internal constant CAPACITY_2 = 30;
//     uint256 internal constant CAPACITY_3 = 40;

//     uint256 internal constant PREMIUMRATIO_1 = 200;
//     uint256 internal constant PREMIUMRATIO_2 = 250;
//     uint256 internal constant PREMIUMRATIO_3 = 400;

//     uint256 internal constant PAYOUT = 1000e6;
//     uint256 internal constant LIQUIDITY = 1000 ether;

//     uint256 internal constant VOTE_FOR = 1;
//     uint256 internal constant VOTE_AGAINST = 2;
//     uint256 internal constant VOTE_AMOUNT = 100 ether;

//     uint256 internal constant PROPOSE_TIME = 0;
//     uint256 internal constant REPORT_TIME = 0;

//     uint256 internal constant PROPOSAL_VOTE_TIME = 0;
//     uint256 internal constant INCIDENT_VOTE_TIME = PENDING_PERIOD;

//     uint256 internal constant PROPOSAL_SETTLE_TIME =
//         PROPOSAL_VOTE_TIME + PROPOSAL_VOTING_PERIOD;
//     uint256 internal constant INCIDENT_SETTLE_TIME =
//         INCIDENT_VOTE_TIME + INCIDENT_VOTING_PERIOD;

//     IPriorityPool internal joePool;
//     PriorityPool internal ptpPool;
//     IPriorityPool internal gmxPool;

//     MockERC20 internal joe;
//     MockERC20 internal ptp;
//     MockERC20 internal gmx;

//     address internal crJoeAddress;

//     address internal joeLPAddress;

//     function setUp() public {
//         setUpContracts();
//         vm.warp(0);
//         // Deploy one protocol token
//         joe = new MockERC20("JoeToken", "JOE", 18);
//         ptp = new MockERC20("PTPToken", "PTP", 18);
//         gmx = new MockERC20("GMXToken", "GMX", 18);

//         // Deploy one priority pool by owner
//         joePool = IPriorityPool(
//             priorityPoolFactory.deployPool(
//                 "TraderJoe",
//                 address(joe),
//                 CAPACITY_1,
//                 PREMIUMRATIO_1
//             )
//         );

//         joeLPAddress = joePool.currentLPAddress();

//         // Mint shield to provide liquidity
//         shield.mint(CHARLIE, 1000 ether);

//         vm.prank(CHARLIE);
//         shield.approve(address(policyCenter), LIQUIDITY);

//         // Provide Liquidity by one user
//         vm.prank(CHARLIE);
//         policyCenter.provideLiquidity(LIQUIDITY);

//         // Propose a new priority pool
//         deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
//         vm.warp(PROPOSE_TIME);
//         vm.prank(CHARLIE);
//         onboardProposal.propose(
//             "Platypus",
//             address(ptp),
//             CAPACITY_2,
//             PREMIUMRATIO_2
//         );

//         // Proopose a new priority pool
//         deg.mintDegis(CHARLIE, PROPOSE_THRESHOLD);
//         vm.warp(PROPOSE_TIME);
//         vm.prank(CHARLIE);
//         onboardProposal.propose(
//             "GMX",
//             address(gmx),
//             CAPACITY_3,
//             PREMIUMRATIO_3
//         );

//         // Fund exchange
//         deg.mintDegis(address(exchange), 1000 ether);
//         shield.mint(address(exchange), 1000 ether);
//         MockERC20(policyCenter.USDC()).mint(address(exchange), 1000 ether * SCALE);
//         joe.mint(address(exchange), 1000 ether * SCALE);
//         ptp.mint(address(exchange), 1000 ether * SCALE);
//         gmx.mint(address(exchange), 1000 ether * SCALE);

//         shield.mint(ALICE, LIQUIDITY);
//         vm.prank(ALICE);
//         shield.approve(address(policyCenter), LIQUIDITY);
//         vm.prank(ALICE);
//         policyCenter.provideLiquidity(LIQUIDITY);
        
//        (uint256 price, uint256 length) = joePool.coverPrice(PAYOUT, 3);
//         vm.prank(CHARLIE);
//         joe.approve(address(policyCenter), type(uint256).max);
//         joe.mint(CHARLIE, price * SCALE);
//         vm.prank(CHARLIE);
//         crJoeAddress = policyCenter.buyCover(
//             1,
//             PAYOUT,
//             3,
//             (price * 11) / 10
//         );

//         deg.mintDegis(CHARLIE, REPORT_THRESHOLD);
//         vm.warp(REPORT_TIME);
//         vm.prank(CHARLIE);
//         incidentReport.report(1, PAYOUT);

//         // Preparations
//         veDEG.mint(ALICE, VOTE_AMOUNT * 2);
//         veDEG.mint(BOB, VOTE_AMOUNT * 2);
//     }

//     function _voteReport() private {
//         vm.warp(INCIDENT_VOTE_TIME);
//         incidentReport.startVoting(1);
//         vm.prank(ALICE);
//         incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
//         vm.prank(BOB);
//         incidentReport.vote(1, VOTE_FOR, VOTE_AMOUNT);
//     }

//     function _voteProposal() private {
//         vm.warp(PROPOSAL_VOTE_TIME);
//         onboardProposal.startVoting(1);
//         vm.prank(ALICE);
//         onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);
//         vm.prank(BOB);
//         onboardProposal.vote(1, VOTE_FOR, VOTE_AMOUNT);
//     }

//     function testExecute() public {
//         // # --------------------------------------------------------------------//
//         // # Should not be able to execute Proposal prior to start voting # //
//         // # --------------------------------------------------------------------//

//         vm.warp(PROPOSAL_SETTLE_TIME);
//         vm.expectRevert(Executor__ProposalNotSettled.selector);
//         executor.executeProposal(1);

//         // pool counter should not be increased and no new pool should be created
//         assertEq(priorityPoolFactory.poolCounter(), 1);

//         console.log(unicode"✅ Not execute a proposal prior to start voting");

//         // # --------------------------------------------------------------------//
//         // # Should not be able to execute Incident prior to start voting # //
//         // # --------------------------------------------------------------------//

//         vm.warp(INCIDENT_SETTLE_TIME);
//         vm.expectRevert(Executor__ReportNotSettled.selector);
//         executor.executeReport(1);

//         // joe pool should not be liquidated after execution attempt
//         // liquidation means deploying new generations of lp tokens
//         assertEq(joePool.currentLPAddress(), joeLPAddress);

//         console.log(unicode"✅ Not execute a report prior to start voting");

//         // # --------------------------------------------------------------------//
//         // # Should not be able to execute Proposal during voting # //
//         // # --------------------------------------------------------------------//

//         // vote for pool proposal and incident report
//         _voteProposal();
//         _voteReport();

//         uint256 snapshot_1 = vm.snapshot();

//         vm.expectRevert(Executor__ProposalNotSettled.selector);
//         executor.executeProposal(1);

//         assertEq(priorityPoolFactory.poolCounter(), 1);

//         console.log(unicode"✅ Not execute a proposal during voting");

//         // # --------------------------------------------------------------------//
//         // # Should not be able to execute Incident during voting # //
//         // # --------------------------------------------------------------------//

//         vm.expectRevert(Executor__ReportNotSettled.selector);
//         executor.executeReport(1);

//         assertEq(joePool.currentLPAddress(), joeLPAddress);

//         console.log(unicode"✅ Not execute a report during voting");

//         // # --------------------------------------------------------------------//
//         // # Should not be able to execute Proposal not settled # //
//         // # --------------------------------------------------------------------//

//         // revert to previous snapshot and take a new snapshot
//         vm.revertTo(snapshot_1);
//         uint256 snapshot_2 = vm.snapshot();

//         vm.expectRevert(Executor__ProposalNotSettled.selector);
//         vm.warp(PROPOSAL_SETTLE_TIME);
//         executor.executeProposal(1);

//         console.log(unicode"✅ Not execute a proposal not settled");

//         // # --------------------------------------------------------------------//
//         // # Should not be able to execute Incident not settled # //
//         // # --------------------------------------------------------------------//

//         vm.expectRevert(Executor__ReportNotSettled.selector);
//         vm.warp(INCIDENT_SETTLE_TIME);
//         executor.executeReport(1);

//         assertEq(joePool.currentLPAddress(), joeLPAddress);

//         console.log(unicode"✅ Not execute a report not settled");

//         // # --------------------------------------------------------------------//
//         // # Should able to execute Proposal after settle # //
//         // # --------------------------------------------------------------------//

//         // revert to previous snapshot and take a new snapshot
//         vm.revertTo(snapshot_2);

//         vm.warp(PROPOSAL_SETTLE_TIME + 1);

//         // Settle proposal
//         onboardProposal.settle(1);

//         // Get proposal record
//         OnboardProposal.Proposal memory proposal = onboardProposal.getProposal(
//             1
//         );
//         assertEq(proposal.status, SETTLED_STATUS);
//         assertEq(proposal.result, PASS_RESULT);

//         // New ptp pool
//         ptpPool = PriorityPool(executor.executeProposal(1));

//         assertTrue(executor.proposalExecuted(1));

//         assertEq(ptpPool.maxCapacity(), CAPACITY_2);
//         assertEq(ptpPool.basePremiumRatio(), PREMIUMRATIO_2);
//         // assertEq(ptpPool.priorityPoolFactory(), address(priorityPoolFactory));
//         // assertEq(ptpPool.weightedFarmingPool(), address(farmingPool));
//         // assertEq(ptpPool.protectionPool(), address(protectionPool));
//         // assertEq(ptpPool.policyCenter(), address(policyCenter));
//         // assertEq(ptpPool.payoutPool(), address(payoutPool));

//         assertEq(ptpPool.coverIndex(), 10000);
//         assertEq(ptpPool.priceIndex(ptpPool.currentLPAddress()), SCALE);

//         assertEq(ptpPool.generation(), 1);

//         console.log(unicode"✅ Execute a settled proposal");

//         // # --------------------------------------------------------------------//
//         // # Should able to execute Report after settle # //
//         // # --------------------------------------------------------------------//

//         vm.warp(INCIDENT_SETTLE_TIME + 1);

//         // Settle incident report
//         incidentReport.settle(1);

//         executor.executeReport(1);

//         assertTrue(executor.reportExecuted(1));

//         IncidentReport.Report memory report = incidentReport.getReport(1);

//         // Check the report record is intanct
//         assertEq(report.poolId, 1);
//         assertEq(report.reporter, CHARLIE);
//         assertEq(report.reportTimestamp, REPORT_TIME);
//         assertEq(report.status, SETTLED_STATUS);
//         assertEq(report.payout, PAYOUT);
//         assertEq(report.result, PASS_RESULT);

//         // Pool should be liquidated
//         assertTrue(joePool.currentLPAddress() != joeLPAddress);

//         console.log(unicode"✅ Execute a settled report");

//         // # --------------------------------------------------------------------//
//         // # Should not able to execute Report twice # //
//         // # --------------------------------------------------------------------//

//         vm.expectRevert(Executor__AlreadyExecuted.selector);
//         executor.executeReport(1);

//         console.log(unicode"✅ Not execute a report twice");


//         // # --------------------------------------------------------------------//
//         // # Should not able to execute Proposal twice # //
//         // # --------------------------------------------------------------------//

//         vm.expectRevert(Executor__AlreadyExecuted.selector);
//         executor.executeProposal(1);

//         console.log(unicode"✅ Not execute a Proposal twice");

//     }
// }
