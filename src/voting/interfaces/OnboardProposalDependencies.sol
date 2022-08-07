// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IExecutor.sol";
import "../../interfaces/IInsurancePoolFactory.sol";

abstract contract OnboardProposalDependencies {
    address public executor;
    address public insurancePoolFactory;

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setInsurancePoolFactory(address _insurancePoolFactory)
        internal
        virtual
    {
        insurancePoolFactory = _insurancePoolFactory;
    }
}
