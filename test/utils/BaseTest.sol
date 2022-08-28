// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

/**
 * @notice Some helper functions for running test in Solidity
 */
contract BaseTest is Test {
    address public constant ZERO_ADDRESS = address(0);

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );

        vm.label(addr, name);
        return addr;
    }

    function giveAssets(
        address _token,
        address _user,
        uint256 _amount
    ) public {
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            _user,
            _amount
        );

        (bool success, ) = _token.call(data);

        require(success);
    }

    function _haveEther(address _user, uint256 _amount) internal {
        vm.deal(_user, _amount);
    }

    function _txSender(address _msgSender) internal {
        vm.prank(_msgSender);
    }

    function _time(uint256 _timeStamp) internal {
        vm.warp(_timeStamp);
    }
}

// ! Comments template for writing test in Solidity
// ! ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓

// # --------------------------------------------------------------------//
// # {Writing your test description here}# //
// # --------------------------------------------------------------------//

// * {Writing the important comments here}

// {Write the comments here}
