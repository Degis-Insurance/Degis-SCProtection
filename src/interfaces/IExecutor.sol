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
    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);

    function deg() view external returns (address);
    function executeProposal(uint256 _proposalId) external returns (address);
    function executeReport(uint256 _reportId) external;
    function executor() view external returns (address);
    function incidentReport() view external returns (address);
    function insurancePoolFactory() view external returns (address);
    function onboardProposal() view external returns (address);
    function owner() view external returns (address);
    function policyCenter() view external returns (address);
    function proposalBuffer() view external returns (uint256);
    function reinsurancePool() view external returns (address);
    function renounceOwnership() external;
    function reportBuffer() view external returns (uint256);
<<<<<<< HEAD
    function setBuffers(uint256 _proposalBuffer, uint256 _reportBuffer) external;
    function setDeg(address _deg) external;
=======
    function setBuffers(uint256 _poolBuffer, uint256 _reportBuffer) external;
   
>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
    function setExecutor(address _executor) external;
    function setIncidentReport(address _incidentReport) external;
    function setInsurancePoolFactory(address _insurancePoolFactory) external;
    function setOnboardProposal(address _onboardProposal) external;
    function setPolicyCenter(address _policyCenter) external;
    function setReinsurancePool(address _reinsurancePool) external;
    
    function shield() view external returns (address);
    function transferOwnership(address newOwner) external;
    function veDeg() view external returns (address);
}