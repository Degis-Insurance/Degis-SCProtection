// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPool.sol";
import "../../interfaces/IPriorityPoolFactory.sol";
import "../../interfaces/IOnboardProposal.sol";
import "../../interfaces/IIncidentReport.sol";
import "../../interfaces/ITreasury.sol";


abstract contract ExecutorDependencies {
    address public priorityPoolFactory;
    address public incidentReport;
    address public onboardProposal;
    address public treasury;
}
