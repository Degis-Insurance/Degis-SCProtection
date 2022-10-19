// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ProtectionPoolMiningToken is ERC20Upgradeable {
    address public protectionPool;

    function initialize(
        string memory _name,
        string memory _symbol,
        address _protectionPool
    ) public initializer {
        __ERC20_init(_name, _symbol);

        protectionPool = _protectionPool;
    }

    modifier onlyProtectionPool() {
        require(msg.sender == protectionPool, "Only protection pool");
        _;
    }

    function mint(address _to, uint256 _amount) external onlyProtectionPool {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external onlyProtectionPool {
        _burn(_to, _amount);
    }
}
