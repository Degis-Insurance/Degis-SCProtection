// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPriorityPoolFactory.sol";

abstract contract OnboardProposalDependencies {
    IPriorityPoolFactory public priorityPoolFactory;
}
