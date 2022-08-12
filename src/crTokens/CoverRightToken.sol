// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IIncidentReport.sol";

import "../libraries/DateTime.sol";

contract CoverRightToken is ERC20, ReentrancyGuard {
    address public incidentReport;
    address public policyCenter;

    uint256 public expiry;

    string public POOL_NAME;
    uint256 public immutable POOL_ID;

    uint256 public constant EXCLUDE_DAYS = 2;

    // User address => start timestamp => cover amount
    mapping(address => mapping(uint256 => uint256)) public coverStartFrom;

    constructor(
        string memory _name,
        string memory _poolName,
        uint256 _poolId,
        uint256 _expiry
    ) ERC20(_name, "crToken") {
        expiry = _expiry;

        POOL_NAME = _poolName;
        POOL_ID = _poolId;
    }

    function mint(
        uint256 _poolId,
        address _user,
        uint256 _amount
    ) external nonReentrant {
        require(_amount > 0, "Zero Amount");
        require(_poolId == POOL_ID, "Wrong pool id");
        require(msg.sender == policyCenter, "Only policy center");

        uint256 effectiveFrom = _getEOD(
            block.timestamp + EXCLUDE_DAYS * 1 days
        );

        coverStartFrom[_user][effectiveFrom] += _amount;

        _mint(_user, _amount);
    }

    function getClaimableOf(address _user) external view returns (uint256) {
        uint256 exclusion = getExcludedCoverageOf(_user);
        uint256 balance = balanceOf(_user);

        if (exclusion > balance) return 0;
        else return balance - exclusion;
    }

    function getExcludedCoverageOf(address _user)
        public
        view
        returns (uint256 exclusion)
    {
        (, uint256 reportTimestamp, , , , , , , , ) = IIncidentReport(
            incidentReport
        ).reports(POOL_ID);

        // Check those bought within 2 days
        for (uint256 i; i < EXCLUDE_DAYS; ++i) {
            uint256 date = _getEOD(reportTimestamp - (i * 1 days));

            exclusion += coverStartFrom[_user][date];
        }
    }

    /**
     * @notice Get the timestamp at the end of the day
     */
    function _getEOD(uint256 _timestamp) private pure returns (uint256) {
        (uint256 year, uint256 month, uint256 day) = DateTimeLibrary
            .timestampToDate(_timestamp);
        return
            DateTimeLibrary.timestampFromDateTime(year, month, day, 23, 59, 59);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal view override {
        if (block.timestamp > expiry) {
            require(to == address(0), "Expired crToken");
        }

        // crTokens can only be used for claim
        if (from != address(0) && to != address(0)) {
            require(to == policyCenter, "Only to policyCenter");
        }
    }
}
