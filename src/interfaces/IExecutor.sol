// SPDX-License-Identifier: GPL-3.0-or-later

/*
 //======================================================================\\
 //======================================================================\\
  *******         **********     ***********     *****     ***********
  *      *        *              *                 *       *
  *        *      *              *                 *       *
  *         *     *              *                 *       *
  *         *     *              *                 *       *
  *         *     **********     *       *****     *       ***********
  *         *     *              *         *       *                 *
  *         *     *              *         *       *                 *
  *        *      *              *         *       *                 *
  *      *        *              *         *       *                 *
  *******         **********     ***********     *****     ***********
 \\======================================================================//
 \\======================================================================//
*/

pragma solidity ^0.8.13;

interface IExecutor {
    event NewPoolEecuted(address poolAddress, uint256 proposalId, address protocol);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event QueuePool(uint256 proposalId, uint256 maxCapacity, uint256 ends);
    event QueueReport(uint256 reportId, uint256 poolId, uint256 ends);
    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);

    function cancelNewPool(uint256 _proposalId) external;
    function cancelReport(uint256 _reportId) external;
    function deg() view external returns (address);
    function executeNewPool(uint256 _proposalId) external returns (address newPool);
    function executeReport(uint256 _reportId) external;
    function executor() view external returns (address);
    function getQueuedReportById(uint256 _reportId) view external returns (uint256, uint256, bool, bool);
    function insurancePoolFactory() view external returns (address);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function poolBuffer() view external returns (uint256);
    function proposalCenter() view external returns (address);
    function queuePool(string memory _protocolName, uint256 _proposalId, address _protocol, uint256 _maxCapacity, uint256 _initialpolicyPricePerShield, bool _pending, bool _approved) external;
    function queueReport(bool _pending, bool _approved, uint256 _reportId, uint256 _poolId) external;
    function queuedPoolsById(uint256) view external returns (string memory protocolName, address protocol, uint256 maxCapacity, uint256 initialpolicyPricePerShield, uint256 queueEnds, bool pending, bool approved);
    function queuedReportsById(uint256) view external returns (uint256 poolId, uint256 queueEnds, bool pending, bool approved);
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
    function reportBuffer() view external returns (uint256);
    function setBuffers(uint256 _poolBuffer, uint256 _reportBuffer) external;
    function setDeg(address _deg) external;
    function setExecutor(address _executor) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setPolicyCenter(address _policyCenter) external;
    function setProposalCenter(address _proposalCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    function setShield(address _shield) external;
    function setVeDeg(address _veDeg) external;
    function shield() view external returns (address);
    function transferOwnership(address newOwner) external;
    function veDeg() view external returns (address);
}
