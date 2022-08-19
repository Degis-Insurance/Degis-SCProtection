// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./CoverRightToken.sol";
import "../interfaces/IPolicyCenter.sol";
import "../util/OwnableWithoutContext.sol";

/**
 * @notice Factory for deploying crTokens
 */
contract CoverRightTokenFactory is OwnableWithoutContext {

    mapping(bytes32 => bool) public deployed;

    mapping(bytes32 => address) public saltToAddress;


    address public policyCenter;

    event NewCRTokenDeployed(
        uint256 poolId,
        string tokenName,
        uint256 expiry,
        address tokenAddress
    );

    constructor(address _policyCenter) OwnableWithoutContext(msg.sender) {
        policyCenter = _policyCenter;
    }

    function setPolicyCenter(address _policyCenter)  public onlyOwner {
        policyCenter = _policyCenter;
    }

    function deployCRToken(
        string calldata _poolName,
        uint256 _poolId,
        string calldata _tokenName,
        uint256 _expiry
    ) external returns (address newCRToken) {
        require(_expiry > 0, "Zero expiry date");

        bytes32 salt = keccak256(abi.encodePacked(_poolId, _expiry));

        require(!deployed[salt], "already deployed");
        deployed[salt] = true;

        bytes memory bytecode = _getCRTokenBytecode(
            _poolName,
            _poolId,
            _tokenName,
            _expiry
        );

        newCRToken = _deploy(bytecode, salt);
        saltToAddress[salt] = newCRToken;

        emit NewCRTokenDeployed(_poolId, _tokenName, _expiry, newCRToken);
    }

    function _getCRTokenBytecode(
        string memory _poolName,
        uint256 _poolId,
        string memory _tokenName,
        uint256 _expiry
    ) internal pure returns (bytes memory code) {
        bytes memory bytecode = type(CoverRightToken).creationCode;

        code = abi.encodePacked(
            bytecode,
            abi.encode(_tokenName, _poolId, _poolName, _expiry)
        );
    }

    /**
     * @notice Deploy function with create2
     * @param code Byte code of the contract (creation code)
     * @param salt Salt for the deployment
     * @return addr The deployed contract address
     */
    function _deploy(bytes memory code, bytes32 salt)
        internal
        returns (address addr)
    {
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }
}
