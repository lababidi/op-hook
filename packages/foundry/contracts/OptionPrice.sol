// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "./IOptionToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


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
    function getPrice(IUniswapV3Pool pool) internal pure returns (uint256) {
        uint8 decimals0 = IERC20Metadata(pool.token0()).decimals();
        uint8 decimals1 = IERC20Metadata(pool.token1()).decimals();
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        // priceX96 is Q64.96, so we square to get the ratio
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        uint256 price = (priceX192 * 10 ** (decimals1 - decimals0)) >> 192;

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

    function getCollateralPrice(IERC20 collateral) external view returns (uint256) {
        return PriceMath.getPrice(IUniswapV3Pool(pool[address(collateral)]));
    }

    // Black-Scholes option pricing formula (returns price with 18 decimals)
    // underlying: price of the underlying asset (18 decimals)
    // strike: strike price (18 decimals)
    // timeToExpiration: time to expiration in seconds
    // volatility: annualized volatility (scaled by 1e18, e.g. 0.2 * 1e18 for 20%)
    // riskFreeRate: annualized risk-free rate (scaled by 1e18, e.g. 0.05 * 1e18 for 5%)
    // isCall: true for call, false for put
    function blackScholesPrice(
        uint256 underlying,
        uint256 strike,
        uint256 timeToExpiration,
        uint256 volatility,
        uint256 riskFreeRate,
        bool isCall
    ) public pure returns (uint256) {
        // All values are in 1e18 fixed point
        // timeToExpiration is in seconds, convert to years (divide by 31536000)
        if (timeToExpiration == 0) {
            // Option has expired
            if (isCall) {
                return underlying > strike ? underlying - strike : 0;
            } else {
                return strike > underlying ? strike - underlying : 0;
            }
        }

        uint256 t = (timeToExpiration * 1e18) / 31536000; // t in years, 1e18 fixed point

        // sigma * sqrt(t)
        uint256 sigmaSqrtT = sqrt((volatility * volatility * t) / 1e18);

        // ln(underlying/strike)
        int256 lnUS = ln(int256(underlying * 1e18 / strike));

        // (r + 0.5 * sigma^2) * t
        int256 r = int256(riskFreeRate);
        int256 halfSigma2 = int256((volatility * volatility) / 2);
        int256 mu = ((r + int256(halfSigma2)) * int256(t)) / int256(1e18);

        // d1 = (ln(U/S) + (r + 0.5*sigma^2)*t) / (sigma*sqrt(t))
        int256 d1 = (lnUS + mu) * int256(1e18) / int256(sigmaSqrtT);

        // d2 = d1 - sigma*sqrt(t)
        int256 d2 = d1 - int256(sigmaSqrtT);

        // N(d1), N(d2)
        uint256 Nd1 = normCDF(d1);
        uint256 Nd2 = normCDF(d2);

        // exp(-r*t)
        uint256 expRT = exp(-r * int256(t) / int256(1e18));

        uint256 price;
        if (isCall) {
            // C = U * N(d1) - S * exp(-r*t) * N(d2)
            price = (underlying * Nd1) / 1e18 - (strike * expRT / 1e18) * Nd2 / 1e18;
        } else {
            // P = S * exp(-r*t) * N(-d2) - U * N(-d1)
            price = (strike * expRT / 1e18) * normCDF(-d2) / 1e18 - (underlying * normCDF(-d1)) / 1e18;
        }
        return price;
    }

    // --- Math helpers ---

    // Natural logarithm (ln) for 1e18 fixed point, returns 1e18 fixed point
    function ln(int256 x) internal pure returns (int256) {
        // Use log2(x) * ln(2)
        require(x > 0, "ln input must be positive");
        int256 log2x = log2(x);
        // ln(2) ~ 0.693147180559945309417232121458
        return (log2x * 693147180559945309) / 1e18;
    }

    // log2(x) for 1e18 fixed point, returns 1e18 fixed point
    function log2(int256 x) internal pure returns (int256) {
        require(x > 0, "log2 input must be positive");
        int256 n = 0;
        while (x < 1e18) {
            x *= 2;
            n -= 1e18;
        }
        while (x >= 2e18) {
            x /= 2;
            n += 1e18;
        }
        int256 y = x - 1e18;
        int256 z = y;
        int256 w = y;
        for (uint8 i = 1; i < 20; i++) {
            n += z / int256(i);
            w = (w * y) / 1e18;
            z = w / int256(i + 1);
            n -= z;
        }
        return n;
    }

    // Exponential function e^x, x in 1e18 fixed point, returns 1e18 fixed point
    function exp(int256 x) internal pure returns (uint256) {
        // Use Taylor expansion for small x, or repeated squaring for larger x
        // For simplicity, use a few terms of Taylor expansion
        int256 sum = 1e18;
        int256 term = 1e18;
        for (uint8 i = 1; i < 20; i++) {
            term = (term * x) / int256(1e18) / int256(i);
            sum += term;
            if (term == 0) break;
        }
        return uint256(sum);
    }

    // Standard normal CDF using Abramowitz & Stegun approximation, input x in 1e18, output 1e18
    function normCDF(int256 x) internal pure returns (uint256) {
        // constants
        int256 a1 = 254829592;
        int256 a2 = -284496736;
        int256 a3 = 142141374;
        int256 a4 = -35476517;
        int256 a5 = 3015300;
        int256 p = 3275911;

        int256 sign = 1;
        if (x < 0) {
            sign = -1;
            x = -x;
        }
        int256 t = 1e18 * 1e6 / (1e6 + (p * x) / 1e12); // t = 1 / (1 + p*x)
        int256 y = (((((a5 * t) / 1e6 + a4) * t) / 1e6 + a3) * t / 1e6 + a2) * t / 1e6 + a1;
        y = (y * t) / 1e6;
        y = 1e18 - (y * exp(-((x * x) / 2e18))) / 1e18;
        if (sign == 1) {
            return (1e18 + y) / 2;
        } else {
            return (1e18 - y) / 2;
        }
    }

    // Square root for 1e18 fixed point, returns 1e18 fixed point
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


    // Returns the price of the token (18 decimals)
    function getPrice(address token) external view returns (uint256) {
        IOptionToken optionToken = IOptionToken(token);
        uint256 expiration = optionToken.expirationDate();
        uint256 strike = optionToken.strike();
        IERC20 collateral = optionToken.collateral();
        IERC20 consideration = optionToken.consideration();
        uint256 optionType = optionToken.isPut() ? 0 : 1;

        uint256 collateralPrice = getCollateralPrice(collateral);

        return collateralPrice ;
    }

    // Returns the inverse price (1e36 / price) to maintain 18 decimals
    function getInversePrice(address token) external view returns (uint256) {
        uint256 price = prices[token];
        require(price > 0, "Price not set");
        // To avoid loss of precision, multiply 1e36 then divide by price
        return 1e36 / price;
    }
}
