// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface ICoverRightTokenFactory {
    function deployCRToken(
        string calldata _poolName,
        uint256 _poolId,
        string calldata _tokenName,
        uint256 _expiry
    ) external returns (address newCRTokenAddress);

    function deployed(bytes32 _salt) external view returns (bool);
}
