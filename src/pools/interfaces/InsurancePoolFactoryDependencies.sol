// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "../../interfaces/IPolicyCenter.sol";

abstract contract InsurancePoolFactoryDependencies {
    address public reinsurancePool;
    address public policyCenter;
    address public executor;

    function _setExecutor(address _executor) internal virtual {
        executor = _executor;
    }

    function _setReinsurancePool(address _reinsurancePool) internal virtual {
        reinsurancePool = _reinsurancePool;
    }

    function _setPolicyCenter(address _policyCenter) internal virtual {
        policyCenter = _policyCenter;
    }

}
