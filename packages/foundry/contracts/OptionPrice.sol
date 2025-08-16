// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IOptionToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function slot0() external view returns (
        uint160 sqrtPriceX96, int24 tick, uint16 observationIndex,
        uint16 observationCardinality, uint16 observationCardinalityNext,
        uint8 feeProtocol, bool unlocked
    );
}
    

library PriceMath {
    // Returns price of 1 WETH in USDC with 18 decimals precision
    function getWethPriceInUsdc(uint160 sqrtPriceX96) internal pure returns (uint256) {
        // priceX96 is Q64.96, so we square to get the ratio
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        // Shift down by 2^192 to normalize
        // price = (token1/token0) * 10^(decimals1 - decimals0)
        // Here: WETH = token0 (18 decimals), USDC = token1 (6 decimals)
        // So multiply by 10^(6) / 10^(18) = 10^(-12)
        // To avoid loss, compute as: (priceX192 * 1e6) / (1e18 << 192)
        uint256 price = (priceX192 * 1e6) >> 192;

        return price;
    }
}


contract OptionPrice {
    // For demonstration, we use a simple mapping to store prices for each token address.
    // In production, this would be replaced by a real oracle or pricing logic.
    mapping(address => uint256) public prices; // price with 18 decimals

    mapping(address => address) public pool; //we're sticking to USDC for now and WETH

    // Set price for a token (for testing/demo purposes)
    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function getExpiration(address token) external view returns (uint256) {
        return IOptionToken(token).expirationDate();
    }


    // Returns the price of the token (18 decimals)
    function getPrice(address token) external view returns (uint256) {
        IOptionToken optionToken = IOptionToken(token);
        uint256 expiration = optionToken.expirationDate();
        uint256 strike = optionToken.strike();
        IERC20 collateral = optionToken.collateral();
        IERC20 consideration = optionToken.consideration();
        uint256 optionType = optionToken.isPut() ? 0 : 1;

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool[token]).slot0();
        uint256 sqrtPrice = uint256(sqrtPriceX96) >> 96;
        uint256 price = sqrtPrice * sqrtPrice ;
        uint256 wethDecimals = 18;
        uint256 usdcDecimals = 6;
        uint256 wethPrice = price * 10 ** (wethDecimals - usdcDecimals);

        return price;
    }

    // Returns the inverse price (1e36 / price) to maintain 18 decimals
    function getInversePrice(address token) external view returns (uint256) {
        uint256 price = prices[token];
        require(price > 0, "Price not set");
        // To avoid loss of precision, multiply 1e36 then divide by price
        return 1e36 / price;
    }
}
