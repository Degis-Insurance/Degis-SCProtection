// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./BaseTest.sol";

import "src/core/PolicyCenter.sol";

import "src/pools/priorityPool/PriorityPoolFactory.sol";
import "src/pools/protectionPool/ProtectionPool.sol";

import "src/pools/PayoutPool.sol";
import "src/reward/WeightedFarmingPool.sol";
import "src/pools/PremiumRewardPool.sol";

import "src/voting/incidentReport/IncidentReport.sol";
import "src/voting/onboardProposal/OnboardProposal.sol";

import "src/mock/MockERC20.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/mock/MockSHIELD.sol";

contract ContractSetupBaseTest is BaseTest {
    PolicyCenter internal center;

    PriorityPoolFactory internal factory;
    ProtectionPool internal protectionPool;

    PayoutPool internal payoutPool;

    WeightedFarmingPool internal farmingPool;

    PremiumRewardPool internal premiumPool;

    IncidentReport internal incidentReport;

    OnboardProposal internal onboardProposal;

    MockDEG internal deg;
    MockVeDEG internal veDEG;
    MockShield internal shield;

    function setUpContracts() public {}
}
