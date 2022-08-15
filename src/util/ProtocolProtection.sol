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

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IExchange.sol";
import "../interfaces/IProtectionPool.sol";
import "../interfaces/IPriorityPool.sol";
import "../interfaces/IPriorityPoolFactory.sol";
import "../interfaces/IOnboardProposal.sol";
import "../interfaces/IIncidentReport.sol";
import "../interfaces/IPolicyCenter.sol";
import "../interfaces/IExecutor.sol";
import "../interfaces/IDegisToken.sol";
import "../interfaces/IVeDEG.sol";

pragma solidity ^0.8.13;

contract ProtocolProtection is Ownable {
    uint256 constant SCALE = 1e12;

    // External Address
    address public deg;
    address public veDeg;
    address public shield;

    //
    address public executor;
    address public policyCenter;
    address public incidentReport;
    address public onboardProposal;
    address public proposalCenter;
    address public protectionPool;
    address public priorityPoolFactory;

    constructor() {}

    function setDeg(address _deg) external virtual onlyOwner {
        deg = _deg;
    }

    function setVeDeg(address _veDeg) external virtual onlyOwner {
        veDeg = _veDeg;
    }

    function setShield(address _shield) external virtual onlyOwner {
        shield = _shield;
    }

    function setExecutor(address _executor) external virtual onlyOwner {
        executor = _executor;
    }

    function setPolicyCenter(address _policyCenter) external virtual onlyOwner {
        policyCenter = _policyCenter;
    }

    function setProposalCenter(address _proposalCenter)
        external
        virtual
        onlyOwner
    {
        proposalCenter = _proposalCenter;
    }

    function setIncidentReport(address _incidentReport)
        external
        virtual
        onlyOwner
    {
        incidentReport = _incidentReport;
    }

    function setOnboardProposal(address _onboardProposal)
        external
        virtual
        onlyOwner
    {
        onboardProposal = _onboardProposal;
    }

    function setProtectionPool(address _protectionPool)
        external
        virtual
        onlyOwner
    {
        protectionPool = _protectionPool;
    }

    function setPriorityPoolFactory(address _priorityPoolFactory)
        external
        virtual
        onlyOwner
    {
        priorityPoolFactory = _priorityPoolFactory;
    }
}
