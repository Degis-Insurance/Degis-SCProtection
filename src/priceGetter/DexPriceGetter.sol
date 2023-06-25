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

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IPriceGetter} from "../interfaces/IPriceGetter.sol";

import {IUniswapV2Pair} from "../libraries/IUniswapV2Pair.sol";
import {FixedPoint} from "../libraries/FixedPoint.sol";
import {UniswapV2OracleLibrary} from "../libraries/UniswapV2OracleLibrary.sol";
import {UniswapV2Library} from "../libraries/UniswapV2Library.sol";

/**
 * @title Price Getter for IDO Protection
 *
 * @notice This is the contract for getting price feed from DEX
 *         IDO projects does not have Chainlink feeds so we use DEX TWAP price as oracle
 *
 *         Workflow:
 *         1. Deploy naughty token for the IDO project and set its type as "IDO"
 *         2. Add ido price feed info by calling "addIDOPair" function
 *         3. Set auto tasks start within PERIOD to endTime to sample prices from DEX
 *         4. Call "settleFinalResult" function in core to settle the final price
 */

contract DexPriceGetter is OwnableUpgradeable {
    using FixedPoint for *;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // WETH and USDC address
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Base price getter to transfer the price into USD
    IPriceGetter public basePriceGetter;

    struct IDOPriceInfo {
        address pair; // Pair on TraderJoe
        uint256 decimals; // If no special settings, it would be 0
        uint256 sampleInterval;
        uint256 isToken0;
        uint256 priceAverage;
        uint256 priceCumulativeLast;
        uint256 lastTimestamp;
    }
    // Policy Base Token Name => IDO Info
    mapping(string => IDOPriceInfo) public priceFeeds;

    mapping(address => string) public addressToName;

    mapping(string => bool) public isUSDTPair;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event SamplePrice(
        string policyToken,
        uint256 priceAverage,
        uint256 timestamp
    );

    event NewIDOPair(
        string policyToken,
        address pair,
        uint256 decimals,
        uint256 sampleInterval,
        uint256 isToken0
    );

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize(address _priceGetter) public initializer {
        __Ownable_init();

        basePriceGetter = IPriceGetter(_priceGetter);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function addUSDTPair(
        string calldata _name,
        address _pair,
        uint256 _decimals,
        uint256 _interval
    ) external onlyOwner {
        require(IUniswapV2Pair(_pair).token0() != address(0), "Non exist pair");
        require(
            IUniswapV2Pair(_pair).token0() == USDT ||
                IUniswapV2Pair(_pair).token1() == USDT,
            "Not usdt pair"
        );
        require(priceFeeds[_name].pair == address(0), "Pair already exists");

        IDOPriceInfo storage newFeed = priceFeeds[_name];

        newFeed.pair = _pair;
        // Decimals should keep the priceAverage to have 18 decimals
        // WETH always has 18 decimals
        // USDT has 6 decimals
        // E.g. Pair token both 18 decimals => price decimals 18
        //      (5e18, 10e18) real price 0.5 => we show priceAverage 0.5 * 10^18
        //      Pair token (18, 6) decimals => price decimals 6
        //      (5e18, 10e6) real price 0.5 => we show priceAverage 0.5 * 10^18
        newFeed.decimals = _decimals;
        newFeed.sampleInterval = _interval;

        // Check if the policy base token is token0
        bool isToken0 = !(IUniswapV2Pair(_pair).token0() == USDT);

        newFeed.isToken0 = isToken0 ? 1 : 0;

        (, , newFeed.lastTimestamp) = IUniswapV2Pair(_pair).getReserves();

        // Record the initial priceCumulativeLast
        newFeed.priceCumulativeLast = isToken0
            ? IUniswapV2Pair(_pair).price0CumulativeLast()
            : IUniswapV2Pair(_pair).price1CumulativeLast();

        isUSDTPair[_name] = true;

        emit NewIDOPair(_name, _pair, _decimals, _interval, newFeed.isToken0);
    }

    function addIDOPair(
        string calldata _name,
        address _pair,
        uint256 _decimals,
        uint256 _interval
    ) external onlyOwner {
        require(IUniswapV2Pair(_pair).token0() != address(0), "Non exist pair");
        require(
            IUniswapV2Pair(_pair).token0() == WETH ||
                IUniswapV2Pair(_pair).token1() == WETH,
            "Not avax pair"
        );
        require(priceFeeds[_name].pair == address(0), "Pair already exists");

        IDOPriceInfo storage newFeed = priceFeeds[_name];

        newFeed.pair = _pair;
        // Decimals should keep the priceAverage to have 18 decimals
        // WETH always have 18 decimals
        // E.g. Pair token both 18 decimals => price decimals 18
        //      (5e18, 10e18) real price 0.5 => we show priceAverage 0.5 * 10^18
        //      Pair token (18, 6) decimals => price decimals 6
        //      (5e18, 10e6) real price 0.5 => we show priceAverage 0.5 * 10^18
        newFeed.decimals = _decimals;
        newFeed.sampleInterval = _interval;

        // Check if the policy base token is token0
        bool isToken0 = !(IUniswapV2Pair(_pair).token0() == WETH);

        newFeed.isToken0 = isToken0 ? 1 : 0;

        (, , newFeed.lastTimestamp) = IUniswapV2Pair(_pair).getReserves();

        // Record the initial priceCumulativeLast
        newFeed.priceCumulativeLast = isToken0
            ? IUniswapV2Pair(_pair).price0CumulativeLast()
            : IUniswapV2Pair(_pair).price1CumulativeLast();

        emit NewIDOPair(_name, _pair, _decimals, _interval, newFeed.isToken0);
    }

    /**
     * @notice Set price in avax
     *         Price in avax should be in 1e18
     *
     * @param _policyToken Policy token name
     * @param _price       Price in avax
     */
    function setPrice(string calldata _policyToken, uint256 _price)
        external
        onlyOwner
    {
        priceFeeds[_policyToken].priceAverage = _price;
    }

    function setAddressToName(address _token, string memory _name)
        external
        onlyOwner
    {
        addressToName[_token] = _name;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    function samplePrice(string calldata _policyToken) external {
        IDOPriceInfo storage priceFeed = priceFeeds[_policyToken];

        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(priceFeed.pair);

        // Time between this sampling and last sampling (seconds)
        uint32 timeElapsed = blockTimestamp - uint32(priceFeed.lastTimestamp);

        uint256 decimals = priceFeed.decimals;

        require(
            timeElapsed > priceFeed.sampleInterval,
            "Minimum sample interval"
        );

        // Update priceAverage and priceCumulativeLast
        uint256 newPriceAverage;

        if (priceFeed.isToken0 > 0) {
            newPriceAverage = FixedPoint
                .uq112x112(
                    uint224(
                        ((price0Cumulative - priceFeed.priceCumulativeLast) *
                            10**decimals) / timeElapsed
                    )
                )
                .decode();

            priceFeed.priceCumulativeLast = price0Cumulative;
        } else {
            newPriceAverage = FixedPoint
                .uq112x112(
                    uint224(
                        ((price1Cumulative - priceFeed.priceCumulativeLast) *
                            10**decimals) / timeElapsed
                    )
                )
                .decode();

            priceFeed.priceCumulativeLast = price1Cumulative;
        }

        priceFeed.priceAverage = newPriceAverage;

        // Update lastTimestamp
        priceFeed.lastTimestamp = blockTimestamp;

        emit SamplePrice(_policyToken, newPriceAverage, blockTimestamp);
    }

    /**
     * @notice Get latest price of a token
     *
     * @param _token Address of the token
     *
     * @return price The latest price
     */
    function getLatestPrice(address _token) public returns (uint256) {
        return getLatestPriceFromName(addressToName[_token]);
    }

    /**
     * @notice Get latest price
     *
     * @param _name Policy token name
     *
     * @return price USD price of the base token
     */
    function getLatestPriceFromName(string memory _name)
        public
        returns (uint256 price)
    {
        if (isUSDTPair[_name] == true) price = priceFeeds[_name].priceAverage;
        else {
            // If it is not a USDT pair, need to get WETH price
            uint256 priceInWETH;

            // If token0 is WAVAX, use price1Average
            // Else, use price0Average
            priceInWETH = priceFeeds[_name].priceAverage;

            require(priceInWETH > 0, "Zero Price");

            // AVAX price, 1e18 scale
            uint256 avaxPrice = basePriceGetter.getLatestPrice("WETH");

            // Warning: for DCAR we tempararily double the price because the settlement price is 0.165
            //          but we set it as 0.33 (they changed the ido price after this round online)

            // This final price is also multiplied by 1e18
            price = (avaxPrice * priceInWETH) / 1e18;
        }
    }
}
