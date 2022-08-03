// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

interface ISetAddress {
    function setDeg(address _deg) external;

    function setVeDeg(address _veDeg) external;

    function setShield(address _shield) external;

    function setExecutor(address _executor) external;

    function setPolicyCenter(address _policyCenter) external;

    function setIncidentReport(address _incidentReport) external;

    function setOnboardProposal(address _onboardProposal) external;

    function setReinsurancePool(address _reinsurancePool) external;

    function setInsurancePoolFactory(address _insurancePoolFactory) external;
}

/**
 * @notice Some helper functions for running test in Solidity
 */
contract BaseTest is Test {
    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );

        vm.label(addr, name);
        return addr;
    }

    function setAddress(
        address _dest,
        address _deg,
        address _veDeg,
        address _shield,
        address _executor,
        address _policyCenter,
        address _incidentReport,
        address _onboardProposal,
        address _reinsurancePool,
        address _insurancePoolFactory
    ) public {
        setDeg(_dest, _deg);
        setVeDeg(_dest, _veDeg);
        setShield(_dest, _shield);
        setExecutor(_dest, _executor);
        setPolicyCenter(_dest, _policyCenter);
        setIncidentReport(_dest, _incidentReport);
        setOnboardProposal(_dest, _onboardProposal);
        setReinsurancePool(_dest, _reinsurancePool);
        setInsurancePoolFactory(_dest, _insurancePoolFactory);
    }

    function setDeg(address _dest, address _deg) public {
        // bytes memory data = abi.encodeWithSignature("setDeg(address)", _deg);
        // _dest.call(data);

        ISetAddress(_dest).setDeg(_deg);
    }

    function setVeDeg(address _dest, address _veDeg) public {
        ISetAddress(_dest).setVeDeg(_veDeg);
    }

    function setShield(address _dest, address _shield) public {
        ISetAddress(_dest).setShield(_shield);
    }

    function setExecutor(address _dest, address _executor) public {
        ISetAddress(_dest).setExecutor(_executor);
    }

    function setPolicyCenter(address _dest, address _policyCenter) public {
        ISetAddress(_dest).setPolicyCenter(_policyCenter);
    }

    function setIncidentReport(address _dest, address _incidentReport) public {
        ISetAddress(_dest).setIncidentReport(_incidentReport);
    }

    function setOnboardProposal(address _dest, address _onboardProposal)
        public
    {
        ISetAddress(_dest).setOnboardProposal(_onboardProposal);
    }

    function setReinsurancePool(address _dest, address _reinsurancePool)
        public
    {
        ISetAddress(_dest).setReinsurancePool(_reinsurancePool);
    }

    function setInsurancePoolFactory(address _dest, address _facotry) public {
        ISetAddress(_dest).setInsurancePoolFactory(_facotry);
    }
}
