// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockVeDEG is ERC20 {
    uint256 public constant MAX_UINT256 = type(uint256).max;

    uint8 public _decimals; //How many decimals to show.

    mapping(address => bool) public whitelist;

    mapping(address => uint256) public locked;

    constructor(
        uint256 _initialAmount,
        string memory _tokenName,
        uint8 _decimalUnits,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        _mint(msg.sender, _initialAmount);

        _decimals = _decimalUnits; // Amount of decimals for display purposes

        whitelist[msg.sender] = true;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    modifier whitelisted() {
        require(whitelist[msg.sender], "not whitelisted address");
        _;
    }

    function setWhitelist(address _address, bool _status) public {
        whitelist[_address] = _status;
    }

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }

    function lockVeDEG(address _owner, uint256 _value) public {
        locked[_owner] += _value;
    }

    function unlockVeDEG(address _owner, uint256 _value) public {
        locked[_owner] -= _value;
    }
}
