// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPolicyCenter.sol";

abstract contract PriorityPoolFactoryDependencies {
    address public protectionPool;
    address public policyCenter;
    address public executor;
    address public premiumRewardPool;
    address public payoutPool;

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setProtectionPool(address _protectionPool) internal virtual {
        protectionPool = _protectionPool;
    }

        function _setPremiumRewardPool(address _premiumRewardPool) internal virtual {
        premiumRewardPool = _premiumRewardPool;
    }

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
    }

    function _setPayoutPool(address _payoutPool) internal virtual {
        payoutPool = _payoutPool;
    }
}
