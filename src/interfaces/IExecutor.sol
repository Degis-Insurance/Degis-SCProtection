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
    event NewPoolEecuted(
        address poolAddress,
        uint256 proposalId,
        address protocol
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event ReportExecuted(address pool, uint256 poolId, uint256 reportId);

    function deg() external view returns (address);

    function executeProposal(uint256 _proposalId) external returns (address);

    function executeReport(uint256 _reportId) external;

    function executor() external view returns (address);

    function incidentReport() external view returns (address);

    function priorityPoolFactory() external view returns (address);

    function onboardProposal() external view returns (address);

    function owner() external view returns (address);

    function policyCenter() external view returns (address);

    function poolBuffer() external view returns (uint256);

    function proposalBuffer() external view returns (uint256);

    function protectionPool() external view returns (address);

    function renounceOwnership() external;

    function reportBuffer() external view returns (uint256);

    function setBuffers(uint256 _proposalBuffer, uint256 _reportBuffer)
        external;

    function setDeg(address _deg) external;

    function setExecutor(address _executor) external;

    function setIncidentReport(address _incidentReport) external;

    function setPriorityPoolFactory(address _priorityPoolFactory) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setPolicyCenter(address _policyCenter) external;

    function setProtectionPool(address _protectionPool) external;

    function shield() external view returns (address);

    function transferOwnership(address newOwner) external;

    function veDeg() external view returns (address);
}
