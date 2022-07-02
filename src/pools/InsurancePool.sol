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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../mock/MockShield.sol";
import "./ReinsurancePool.sol";

contract InsurancePool is ERC20 {
    address public reinsuranceAddress;
    address public executorAddress;
    address public policyCenterAddress;

    string public name;
    address public insuredToken;
    bool public paused;
    bool public claimable;
    uint256 public maxCapacity;
    uint256 public liquidity;
    uint256 public liquidityProvisioned;

    constructor(
        string calldata _name,
        address _protocolToken,
        uint256 _maxCapacity,
        uint256 _vaultSplit,
        uint256 _treasurySplit
    ) {
        name = _name;
        insuredToken = _protocolToken;
        maxCapacity = _maxCapacity;
    }

    modifier onlyOwnerOrExecutor() {
        require(msg.sender == owner || msg.sender == executorAddress, "Only owner or executor can call this function");
        _;
    }

    function poolInfo()
        public
        view
        returns (
            string,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (name, insuredToken, maxCapacity, liquidity, claimable);
    }

    function changeRevenueSplit(uint256 _vaultSplit, uint256 _treasurySplit)
        public
    {
        require(msg.sender == owner);
        require(_vaultSplit + _treasurySplit == 100);
        require(_vaultSplit > 0);
        require(_treasurySplit > 0);
        vaultSplit = _vaultSplit;
        treasurySplit = _treasurySplit;
    }

    function setMaxCapacity(uint256 _maxCapacity) external onlyOwner {
        maxCapacity = _maxCapacity;
    }

    function provideLiquidity(uint256 _amount, address _provider) external {
        require(
            _amount < maxCapacity - totalSupply,
            "InsurancePool: provideLiquidity: amount exceeds maxCapacity"
        );
        require(msg.sender == policyCenterAddress, "Not policyCenter");
        require(
            !claimable,
            "Pool has been liquidated, cannot provide new liquidity"
        );
        _mint(_amount, _provider);
        liquidity += _amount;
        liquidityProvisioned[_provider] += _amount;
    }

    function removeLiquidity(uint256 _amount) external {
        require(
            !claimable,
            "Pool has been liquidated, cannot remove liquidity"
        );
        require(
            _amount < totalSupply,
            "InsurancePool: removeLiquidity: amount exceeds totalSupply"
        );

        _burn(_amount);
        liquidity -= _amount;
        ERC20(shield).transfer(address(this), msg.sender, _amount);
    }

    //TODO is claim payout done here or in policy center?
    function claimPayout(uint256 _amount, address _insured) external {
        require(claimable, "InsurancePool: payout: pool is not claimable");
        require(
            msg.sender == policyCenterAddress,
            "claimPayout: sender is not policy center"
        );
        //TODO calculate how much to payout with this amount of lp tokens
        if (liquidity >= _amount) {
            shield.transfer(_insured, _amount);
        } else {
            shield.transfer(_insured, _amount);
            _requestReinsurance(amount - liquidity, msg.sender);
        }
        emit Payout(amount, msg.sender);
    }

    function liquidatePool() external onlyOwnerOrExecutor {
        _setClaimStatus(true);
        uint256 amount = totalSupply;

        emit Liquidation(amount);
    }

    function _setClaimStatus(bool _claimable) internal {
        claimable = _claimable;
    }

    function _requestReinsurance(uin256 _amount, address _addresss) internal {
        ReinsurancePool(reinsuranceAddress).reinsurePool(
            amount - liquidity,
            _address
        );
    }

    //totalSupply < maxCapacity

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //
}
