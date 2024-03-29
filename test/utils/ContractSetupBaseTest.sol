// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./BaseTest.sol";

import "src/core/PolicyCenter.sol";
import "src/core/Executor.sol";

import {PriorityPoolFactory} from "src/pools/priorityPool/PriorityPoolFactory.sol";
import {ProtectionPool} from "src/pools/protectionPool/ProtectionPool.sol";
import {PriorityPool} from "src/pools/priorityPool/PriorityPool.sol";

import "src/pools/payoutPool/PayoutPool.sol";
import "src/reward/farming/WeightedFarmingPool.sol";
import "src/reward/treasury/Treasury.sol";

import "src/voting/incidentReport/IncidentReport.sol";
import "src/voting/onboardProposal/OnboardProposal.sol";

import "src/crTokens/CoverRightToken.sol";
import "src/crTokens/CoverRightTokenFactory.sol";

import "src/mock/MockERC20.sol";
import "src/mock/MockDEG.sol";
import "src/mock/MockVeDEG.sol";
import "src/mock/MockExchange.sol";
import "src/mock/MockPriceGetter.sol";
import "src/mock/MockUSDC.sol";

contract ContractSetupBaseTest is BaseTest {
    PolicyCenter internal policyCenter;
    Executor internal executor;

    PriorityPoolFactory internal priorityPoolFactory;
    ProtectionPool internal protectionPool;

    Treasury internal treasury;
    PayoutPool internal payoutPool;
    WeightedFarmingPool internal farmingPool;

    IncidentReport internal incidentReport;
    OnboardProposal internal onboardProposal;

    CoverRightTokenFactory internal crFactory;

    MockDEG internal deg;
    MockVeDEG internal veDEG;
    MockUSDC internal usdc;

    MockPriceGetter internal priceGetter;
    MockExchange internal exchange;

    function setUpContracts() public {
        // Set up mock tokens
        deg = new MockDEG(0, "Degis", 18, "DEG");
        veDEG = new MockVeDEG(0, "VoteEscrowedDegis", 18, "veDEG");
        usdc = new MockUSDC("MockUSDC", "MockUSDC", 6);

        priceGetter = new MockPriceGetter();
        exchange = new MockExchange();

        _setupProtectionPool();
        _setupFactory();

        _setupPolicyCenter();
        _setupExecutor();

        _setupTreasury();

        _setupFarmingPool();

        _setupIncidentReport();
        _setupOnboardProposal();

        _setupCRFactory();
        _setupPayoutPool();

        _setAddresses();
    }

    function _setupProtectionPool() internal {
        protectionPool = new ProtectionPool(
            address(deg),
            address(veDEG)
        );
    }

    function _setupFactory() internal {
        priorityPoolFactory = new PriorityPoolFactory(
            address(deg),
            address(veDEG),
            address(protectionPool)
        );
    }

    function _setupPolicyCenter() internal {
        policyCenter = new PolicyCenter(
            address(deg),
            address(veDEG),
            address(protectionPool),
            address(usdc)
        );
    }

    function _setupExecutor() internal {
        executor = new Executor();
    }

    function _setupCRFactory() internal {
        crFactory = new CoverRightTokenFactory(
            address(policyCenter),
            address(incidentReport)
        );
    }

    function _setupPayoutPool() internal {
        payoutPool = new PayoutPool(
            address(policyCenter),
            address(crFactory),
            address(priorityPoolFactory)
        );
    }

    function _setupTreasury() internal {
        treasury = new Treasury(
            address(executor),
            address(policyCenter)
        );
    }

    function _setupFarmingPool() internal {
        farmingPool = new WeightedFarmingPool(
            address(policyCenter),
            address(priorityPoolFactory)
        );
    }

    function _setupIncidentReport() internal {
        incidentReport = new IncidentReport(
            address(deg),
            address(veDEG)
        );
    }

    function _setupOnboardProposal() internal {
        onboardProposal = new OnboardProposal(
            address(deg),
            address(veDEG)
        );
    }

    function _setAddresses() internal {
        // Set incident report
        incidentReport.setPriorityPoolFactory(address(priorityPoolFactory));

        // Set onboard proposal
        onboardProposal.setPriorityPoolFactory(address(priorityPoolFactory));

        // Set weighted farming pool
        farmingPool.setPolicyCenter(address(policyCenter));

        // Set protection pool
        protectionPool.setPriorityPoolFactory(address(priorityPoolFactory));
        protectionPool.setPolicyCenter(address(policyCenter));
        protectionPool.setIncidentReport(address(incidentReport));

        // Set policy center
        policyCenter.setProtectionPool(address(protectionPool));
        policyCenter.setPriceGetter(address(priceGetter));
        policyCenter.setPriorityPoolFactory(address(priorityPoolFactory));
        policyCenter.setCoverRightTokenFactory(address(crFactory));
        policyCenter.setWeightedFarmingPool(address(farmingPool));
        policyCenter.setExchange(address(exchange));
        policyCenter.setPayoutPool(address(payoutPool));
        policyCenter.setTreasury(address(treasury));

        // Set executor
        executor.setIncidentReport(address(incidentReport));
        executor.setOnboardProposal(address(onboardProposal));
        executor.setPriorityPoolFactory(address(priorityPoolFactory));
        executor.setTreasury(address(treasury));

        // Set factory
        priorityPoolFactory.setPolicyCenter(address(policyCenter));
        priorityPoolFactory.setExecutor(address(executor));
        priorityPoolFactory.setWeightedFarmingPool(address(farmingPool));
        priorityPoolFactory.setIncidentReport(address(incidentReport));
        priorityPoolFactory.setPayoutPool(address(payoutPool));
    }
}
