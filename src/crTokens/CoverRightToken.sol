// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../util/OwnableWithoutContext.sol";

import "../interfaces/IIncidentReport.sol";

import "../libraries/DateTime.sol";

/**
 * @notice Cover Right Tokens
 *
 *         ERC20 tokens that represent the cover you bought
 *         It is a special token:
 *             1) Can not be transferred to other addresses
 *             2) Has an expiry date
 *
 *         A new crToken will be deployed for each month's policies for a pool
 *         Each crToken will ended at the end timestamp of each month
 *
 *         To calculate a user's balance, we use coverFrom to record it.
 *         E.g.  CRToken CR-JOE-2022-8
 *               You bought X amount at timestamp t1 (in 2022-6 ~ 2022-8)
 *               coverStartFrom[yourAddress][t1] += X
 *
 *         When used for claiming, check your crTokens
 *             1) Not expired
 *             2) Not bought too close to the report timestamp
 *
 */
contract CoverRightToken is ERC20, ReentrancyGuard, OwnableWithoutContext {
    address public incidentReport;
    address public policyCenter;

    uint256 public immutable generation;

    // Expiry date
    uint256 public expiry;

    // Pool name for this crToken
    string public POOL_NAME;

    // Pool id for this crToken
    uint256 public immutable POOL_ID;

    // Those covers bought within 2 days will be excluded
    uint256 public constant EXCLUDE_DAYS = 2;

    // User address => start timestamp => cover amount
    mapping(address => mapping(uint256 => uint256)) public coverStartFrom;

    constructor(
        string memory _poolName,
        uint256 _poolId,
        string memory _name,
        uint256 _expiry,
        uint256 _generation,
        address _policyCenter
    ) ERC20(_name, "crToken") OwnableWithoutContext(msg.sender) {
        expiry = _expiry;

        POOL_NAME = _poolName;
        POOL_ID = _poolId;
        generation = _generation;
        policyCenter = _policyCenter;
    }

    modifier onlyPolicyCenter() {
        require(msg.sender == policyCenter, "Only policy center");
        _;
    }

    function setPolicyCenter(address _policyCenter) public onlyOwner {
        policyCenter = _policyCenter;
    }

    /**
     * @notice Mint new crTokens when buying covers
     *
     * @param _poolId Pool id
     * @param _user   User address
     * @param _amount Amount to mint
     */
    function mint(
        uint256 _poolId,
        address _user,
        uint256 _amount
    ) external onlyPolicyCenter nonReentrant {
        require(_amount > 0, "Zero Amount");
        require(_poolId == POOL_ID, "Wrong pool id");

        uint256 effectiveFrom = _getEOD(
            block.timestamp + EXCLUDE_DAYS * 1 days
        );

        coverStartFrom[_user][effectiveFrom] += _amount;

        _mint(_user, _amount);
    }

    /**
     * @notice Burn crTokens to claim
     *         Only callable from policyCenter
     *
     * @param _poolId Pool id
     * @param _user   User address
     * @param _amount Amount to burn
     */
    function burn(
        uint256 _poolId,
        address _user,
        uint256 _amount
    ) external onlyPolicyCenter nonReentrant {
        require(_amount > 0, "Zero Amount");
        require(_poolId == POOL_ID, "Wrong pool id");

        _burn(_user, _amount);
    }

    /**
     * @notice Get the claimable amount of a user
     *         Claimable means "without those has passed the expiry date"
     */
    function getClaimableOf(address _user) external view returns (uint256) {
        uint256 exclusion = getExcludedCoverageOf(_user);
        uint256 balance = balanceOf(_user);

        if (exclusion > balance) return 0;
        else return balance - exclusion;
    }

    /**
     * @notice Get the excluded amount of a user
     *         Excluded means "without those are bought within a short time before voteTimestamp"
     *
     * @param _user         User address
     *
     * @return exclusion    Amount not able to claim because cover period has ended
     *
     */
    function getExcludedCoverageOf(address _user)
        public
        view
        returns (uint256 exclusion)
    {
        IIncidentReport incident = IIncidentReport(incidentReport);

        uint256 reportAmount = incident.getPoolReportsAmount(POOL_ID);
        uint256 latestReportId = incident.poolReports(
            POOL_ID,
            reportAmount - 1
        );

        (, , , uint256 voteTimestamp, , , , , , , ) = incident.reports(
            latestReportId
        );

        // Check those bought within 2 days
        for (uint256 i; i < EXCLUDE_DAYS; ) {
            uint256 date = _getEOD(voteTimestamp - (i * 1 days));

            exclusion += coverStartFrom[_user][date];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Get the timestamp at the end of the day
     *
     * @param _timestamp Timestamp to be transformed
     *
     * @return endTimestamp End timestamp of that day
     */
    function _getEOD(uint256 _timestamp) private pure returns (uint256) {
        (uint256 year, uint256 month, uint256 day) = DateTimeLibrary
            .timestampToDate(_timestamp);
        return
            DateTimeLibrary.timestampFromDateTime(year, month, day, 23, 59, 59);
    }

    /**
     * @notice Hooks before token transfer
     *         - Can burn expired crTokens (send to zero address)
     *         - Can be minted or used for claim
     *         Other transfers are banned
     *
     * @param from From address
     * @param to   To address
     */
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
