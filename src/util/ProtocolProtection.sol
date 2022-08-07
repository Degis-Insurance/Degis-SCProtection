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

import "../interfaces/IDegisToken.sol";
import "../interfaces/IVeDEG.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IReinsurancePool.sol";
import "../interfaces/IInsurancePool.sol";
import "../interfaces/IInsurancePoolFactory.sol";
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
    address public reinsurancePool;
    address public insurancePoolFactory;

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

<<<<<<< HEAD
    function setProposalCenter(address _proposalCenter) external virtual onlyOwner {
        proposalCenter = _proposalCenter;
    }

    function setIncidentReport(address _incidentReport) external virtual onlyOwner {
=======
    function setIncidentReport(address _incidentReport)
        external
        virtual
        onlyOwner
    {
>>>>>>> 05456c0a196e8fab9f0b49751142cf12c977c2eb
        incidentReport = _incidentReport;
    }

    function setOnboardProposal(address _onboardProposal)
        external
        virtual
        onlyOwner
    {
        onboardProposal = _onboardProposal;
    }

    function setReinsurancePool(address _reinsurancePool)
        external
        virtual
        onlyOwner
    {
        reinsurancePool = _reinsurancePool;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory)
        external
        virtual
        onlyOwner
    {
        insurancePoolFactory = _insurancePoolFactory;
    }
}
