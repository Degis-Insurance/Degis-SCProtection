// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICoverRightToken {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function EXCLUDE_DAYS() view external returns (uint256);
    function POOL_ID() view external returns (uint256);
    function POOL_NAME() view external returns (string memory);
    function allowance(address owner, address spender) view external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) view external returns (uint256);
    function coverStartFrom(address, uint256) view external returns (uint256);
    function decimals() view external returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function expiry() view external returns (uint256);
    function getClaimableOf(address _user) view external returns (uint256);
    function getExcludedCoverageOf(address _user) view external returns (uint256 exclusion);
    function incidentReport() view external returns (address);

    function mint(uint256 _poolId, address _user, uint256 _amount) external;
    function burn(uint256 _poolId, address _user, uint256 _amount) external;
    function name() view external returns (string memory);
    function policyCenter() view external returns (address);
    function symbol() view external returns (string memory);
    function totalSupply() view external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}