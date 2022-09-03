// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "./CoverRightToken.sol";
import "../interfaces/IPolicyCenter.sol";
import "../util/OwnableWithoutContext.sol";

import "forge-std/console.sol";

/**
 * @notice Factory for deploying crTokens
 */
contract CoverRightTokenFactory is OwnableWithoutContext {
    mapping(bytes32 => bool) public deployed;

    mapping(bytes32 => address) public saltToAddress;

    mapping(bytes32 => uint256) public generation;

    address public policyCenter;
    address public incidentReport;

    event NewCRTokenDeployed(
        uint256 poolId,
        string tokenName,
        uint256 expiry,
        uint256 generation,
        address tokenAddress
    );

    constructor(address _policyCenter, address _incidentReport) OwnableWithoutContext(msg.sender) {
        policyCenter = _policyCenter;
        incidentReport = _incidentReport;
    }

    function setPolicyCenter(address _policyCenter) public onlyOwner {
        policyCenter = _policyCenter;
    }

    /**
     * @notice Deploy Cover Right Token for a given pool
     *
     * @param _poolName          Name of Priority Pool
     * @param _poolId         	Pool Id
     * @param _tokenName         Name of insured token (e.g. DEG)
     * @param _expiry         	Expiry date of cover right token
     * @param _generation        Generation of priority pool (1 if no liquidations occurred)
     */
    function deployCRToken(
        string calldata _poolName,
        uint256 _poolId,
        string calldata _tokenName,
        uint256 _expiry,
        uint256 _generation
    ) external returns (address newCRToken) {
        require(_expiry > 0, "Zero expiry date");

        bytes32 salt = keccak256(
            abi.encodePacked(_poolId, _expiry, _generation)
        );

        require(!deployed[salt], "already deployed");
        deployed[salt] = true;

        bytes memory bytecode = _getCRTokenBytecode(
            _poolName,
            _poolId,
            _tokenName,
            _expiry,
            _generation
        );

        newCRToken = _deploy(bytecode, salt);
        saltToAddress[salt] = newCRToken;

        emit NewCRTokenDeployed(
            _poolId,
            _tokenName,
            _expiry,
            _generation,
            newCRToken
        );
    }

    /**
     * @notice Given several parameters, returns the bytecode for deploying a crToken
     *
     * @param _poolName          Name of Priority Pool
     * @param _poolId         	Pool Id
     * @param _tokenName         Name of insured token (e.g. DEG)
     * @param _expiry         	Expiry date of cover right token
     * @param _generation        Generation of priority pool (1 if no liquidations occurred)
     */
    function _getCRTokenBytecode(
        string memory _poolName,
        uint256 _poolId,
        string memory _tokenName,
        uint256 _expiry,
        uint256 _generation
    ) internal view returns (bytes memory code) {
        bytes memory bytecode = type(CoverRightToken).creationCode;

        code = abi.encodePacked(
            bytecode,
            abi.encode(
                _tokenName,
                _poolId,
                _poolName,
                _expiry,
                _generation,
                policyCenter,
                incidentReport
            )
        );
    }

    /**
     * @notice Deploy function with create2
     *
     * @param code      Byte code of the contract (creation code)
     * @param salt      Salt for the deployment
     * @return addr     The deployed contract address
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
