// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IPolicyCenter {
    function storePoolInformation(
        address _pool,
        address _token,
        uint256 _poolId
    ) external;
}
