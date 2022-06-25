// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;


interface IInsurancePool {

    string public name;
    address public insuredToken;
    bool public paused;
    bool public claimable;
    uint256 public maxCapacity;
    
    function setMaxCapacity(uint256 _maxCapacity) external;
    function provideLiquidity(uint256 _amount) external;
    function removeLiquidity(uint256 _amount) external;
    function payout() external;
    function setClaimStatus(bool _claimable) external;

    //totalSupply < maxCapacity
}