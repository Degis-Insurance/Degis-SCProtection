// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IInsurancePool {
    function initialize() external;

    function poolInfo()
        external
        view
        returns (
            string memory,
            address,
            uint256,
            uint256,
            uint256
        );

    function coveragePrice(
        uint256 _amount,
        uint256 _length
    ) external view returns (uint256);

    function paused() external view returns (bool);

    function claimPayout(uint256 _amount) external;

    function claimReward(address _provider) external;

    function liquidatePool() external;

    function setMaxCapacity(uint256 _maxCapacity) external;

    function provideLiquidity(uint256 _amount, address _provider) external;

    function removeLiquidity(uint256 _amount, address _provider) external;

    function addPremium(uint256 _amount) external;

    function buyCoverage(
        uint256 _paid,
        uint256 _amount,
        uint256 _length,
        address _insured
    ) external;

    function setClaimStatus(bool _claimable) external;

    function setPausedInsurancePool(bool _paused) external;

    //totalSupply < maxCapacity
}
