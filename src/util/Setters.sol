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

pragma solidity ^0.8.13;

contract Setters is Ownable {

    address public deg;
    address public veDeg;
    address public shield;
    address public executor;
    address public policyCenter;
    address public proposalCenter;
    address public reinsurancePool;
    address public insurancePoolFactory;

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

    function setProposalCenter(address _proposalCenter) external virtual onlyOwner {
        proposalCenter = _proposalCenter;
    }

    function setReinsurancePool(address _reinsurancePool) external virtual onlyOwner {
        reinsurancePool = _reinsurancePool;
    }

    function setInsurancePoolFactory(address _insurancePoolFactory) external virtual onlyOwner {
        insurancePoolFactory = _insurancePoolFactory;
    }

}