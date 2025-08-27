// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {OptionPrice} from "../contracts/OptionPrice.sol";

contract OptionPriceTest is Test {
    address constant WETH_UNI_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    OptionPrice public optionPrice;

    function setUp() public {
        optionPrice = new OptionPrice(WETH_UNI_POOL);
    }

    // expNeg function tests
    function test_expNeg_zero() public view {
        // exp(-0) = 1
        assertEq(optionPrice.expNeg(0), 1e18, "expNeg(0) should equal 1");
    }
    
    function test_expNeg_one() public view {
        // exp(-1) ≈ 0.3678794411714423215955237701614608674458111310317678345078368016
        // Using 1e18 fixed point: 367879441171442321
        assertApproxEqRel(
            optionPrice.expNeg(1e18), 
            367879441171442321, 
            0.01e18, // 1% tolerance
            "expNeg(1) should be approximately 0.3679"
        );
    }
    
    function test_expNeg_two() public view {
        // exp(-2) ≈ 0.1353352832366126918939994949724844034076315459095758814681588726
        // Using 1e18 fixed point: 135335283236612691
        assertApproxEqRel(
            optionPrice.expNeg(2e18), 
            135335283236612691, 
            0.01e18, // 1% tolerance
            "expNeg(2) should be approximately 0.1353"
        );
    }
    
    function test_expNeg_large_values() public view {
        // Test large values (should return 0 for x > 10)
        assertEq(optionPrice.expNeg(11e18), 0, "expNeg(11) should equal 0");
        assertEq(optionPrice.expNeg(100e18), 0, "expNeg(100) should equal 0");
    }

    // normCDF function tests
    function test_CDF_zero() public view {
        // CDF(0) = 0.5
        assertApproxEqRel(
            optionPrice.normCDF(0), 
            0.5e18, 
            0.01e18, // 1% tolerance
            "CDF(0) should equal 0.5"
        );
    }
    
    function test_CDF_one() public view {
        // CDF(1) ≈ 0.841344746068542948585232545632236508569979607683073846018840
        // Using 1e18 fixed point: 841344746068542948
        assertApproxEqRel(
            optionPrice.normCDF(1e18), 
            uint256(841344746068542948), 
            uint256(5e16), // 5% tolerance due to approximation
            "CDF(1) should be approximately 0.8413"
        );
    }
    
    function test_CDF_negative_one() public view {
        // CDF(-1) ≈ 0.158655253931457051414767454367763491430020392316926153981160
        // Using 1e18 fixed point: 158655253931457051
        assertApproxEqRel(
            optionPrice.normCDF(-1e18), 
            158655253931457051, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(-1) should be approximately 0.1587"
        );
    }
    
    function test_CDF_two() public view {
        // CDF(2) ≈ 0.977249868051820792829203194655283100470870641557131167191311
        // Using 1e18 fixed point: 977249868051820792
        assertApproxEqRel(
            optionPrice.normCDF(2e18), 
            977249868051820792, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(2) should be approximately 0.9772"
        );
    }

    // Black-Scholes pricing tests
    function test_BlackScholes_ATM_call() public view {
        // Test case: ATM call option with 1 year to expiration
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 timeToExpiration = 31536000; // 1 year in seconds
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        bool isCall = true;
        
        uint256 callPrice = optionPrice.blackScholesPrice(
            underlying, 
            strike, 
            timeToExpiration, 
            volatility, 
            riskFreeRate, 
            isCall
        );
        
        // For ATM call with 20% vol and 5% rate, price should be around $10.45
        // Using 1e18 fixed point: 10450000000000000000
        assertApproxEqRel(
            callPrice, 
            10450000000000000000, 
            0.1e18, // 10% tolerance for approximation
            "ATM call option price should be approximately $10.45"
        );
    }
    
    function test_BlackScholes_ATM_put() public view {
        // Test put option (same parameters)
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 timeToExpiration = 31536000; // 1 year in seconds
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        bool isPut = false;
        
        uint256 putPrice = optionPrice.blackScholesPrice(
            underlying, 
            strike, 
            timeToExpiration, 
            volatility, 
            riskFreeRate, 
            isPut
        );
        
        // For ATM put with 20% vol and 5% rate, price should be around $5.57
        // Using 1e18 fixed point: 5570000000000000000
        assertApproxEqRel(
            putPrice, 
            5570000000000000000, 
            0.1e18, // 10% tolerance for approximation
            "ATM put option price should be approximately $5.57"
        );
    }
    
    function test_BlackScholes_expired_ATM_call() public view {
        // Test expired option (timeToExpiration = 0)
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        
        uint256 expiredCallPrice = optionPrice.blackScholesPrice(
            underlying, 
            strike, 
            0, // expired
            volatility, 
            riskFreeRate, 
            true
        );
        
        // For expired ATM call, intrinsic value should be 0
        assertEq(expiredCallPrice, 0, "Expired ATM call should have 0 value");
    }
    
    function test_BlackScholes_expired_ITM_call() public view {
        // Test ITM expired call
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        
        uint256 itmExpiredCallPrice = optionPrice.blackScholesPrice(
            120e18, // $120 underlying
            100e18, // $100 strike
            0, // expired
            volatility, 
            riskFreeRate, 
            true
        );
        
        // For expired ITM call, intrinsic value should be $20
        assertEq(itmExpiredCallPrice, 20e18, "Expired ITM call should have intrinsic value of $20");
    }

    function test_BlackScholes_debug() public view {
        // Test case: ATM call option with 1 year to expiration
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 timeToExpiration = 31536000; // 1 year in seconds
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        bool isCall = true;
        
        // Debug intermediate values
        uint256 t = (timeToExpiration * 1e18) / 31536000;
        console.log("t (years):", t);
        
        uint256 sigmaSqrtT = optionPrice.sqrt((volatility * volatility * t) / 1e18);
        console.log("sigma*sqrt(t):", sigmaSqrtT);
        
        uint256 Ks = underlying * 1e18 / strike;
        console.log("Ks (underlying/strike):", Ks);
        
        int256 lnUS = Ks>1e18 ? optionPrice.ln(Ks) : -optionPrice.ln(1e36/Ks);
        console.log("ln(underlying/strike):", lnUS);
        
        uint256 halfSigma2 = (volatility * volatility) / 2;
        uint256 mu = ((riskFreeRate + halfSigma2) * t) / 1e18;
        console.log("mu ((r + 0.5*sigma^2)*t):", mu);
        
        int256 d1 = (lnUS + int256(mu)) * 1e18 / int256(sigmaSqrtT);
        console.log("d1:", d1);
        
        int256 d2 = d1 - int256(sigmaSqrtT);
        console.log("d2:", d2);
        
        uint256 Nd1 = optionPrice.normCDF(d1);
        uint256 Nd2 = optionPrice.normCDF(d2);
        console.log("N(d1):", Nd1);
        console.log("N(d2):", Nd2);
        
        uint256 expRT = optionPrice.expNeg(riskFreeRate * t / 1e18);
        console.log("exp(-r*t):", expRT);
        
        uint256 callPrice = optionPrice.blackScholesPrice(
            underlying, 
            strike, 
            timeToExpiration, 
            volatility, 
            riskFreeRate, 
            isCall
        );
        console.log("Final call price:", callPrice);
    }

    // ln function tests
    function test_ln_one() public view {
        // ln(1) = 0
        assertEq(optionPrice.ln(1e18), 0, "ln(1) should equal 0");
    }
    
    function test_ln_one_point_five() public view {
        // ln(1.5) ≈ 0.405465108108164381978013115464349136571990423462494197614014
        // Using 1e18 fixed point: 405465108108164381
        assertApproxEqRel(
            optionPrice.ln(15e17), // 1.5 in 1e18 fixed point
            405465108108164381, 
            0.01e18, // 1% tolerance
            "ln(1.5) should be approximately 0.4055"
        );
    }
    
    function test_ln_two() public view {
        // ln(2) ≈ 0.693147180559945309417232121458176568075500134360255254120680
        // Using 1e18 fixed point: 693147180559945309
        assertApproxEqRel(
            optionPrice.ln(2e18), 
            693147180559945309, 
            0.01e18, // 1% tolerance
            "ln(2) should be approximately 0.6931"
        );
    }
    
    function test_ln_one_point_zero_five() public view {
        // ln(1.05) ≈ 0.048790164169432048
        assertApproxEqRel(
            optionPrice.ln(105e16), // 1.05 in 1e18 fixed point
            48790164169432048, 
            0.01e18, // 1% tolerance
            "ln(1.05) should be approximately 0.0488"
        );
    }
    
    function test_ln_boundary_values() public view {
        // Test boundary values
        assertEq(optionPrice.ln(1e18), 0, "ln(1) should equal 0");
        assertEq(optionPrice.ln(2e18), 693147180559945728, "ln(2) should equal grid value");
    }
    
    function test_ln_out_of_range_low() public {
        // Test that out-of-range values revert
        vm.expectRevert("ln: x out of grid range");
        optionPrice.ln(0.5e18); // x < 1
    }
    
    function test_ln_out_of_range_high() public {
        // Test that out-of-range values revert
        vm.expectRevert("ln: x out of grid range");
        optionPrice.ln(3e18); // x > 2
    }

    function test_normCDF_BlackScholes_values() public view {
        // Test the actual values produced by the Black-Scholes calculation
        int256 d1 = 350000000000000000; // 0.35 in 1e18 fixed point (actual value from Black-Scholes)
        int256 d2 = 150000000000000000; // 0.15 in 1e18 fixed point (actual value from Black-Scholes)
        
        console.log("Testing normCDF for d1 = 0.35");
        uint256 Nd1 = optionPrice.normCDF(d1);
        console.log("N(d1):", Nd1);
        
        console.log("Testing normCDF for d2 = 0.15");
        uint256 Nd2 = optionPrice.normCDF(d2);
        console.log("N(d2):", Nd2);
        
        // Expected values for the actual Black-Scholes calculation:
        // N(0.35) ≈ 0.6368
        // N(0.15) ≈ 0.5596
        assertApproxEqRel(Nd1, 636800000000000000, 0.1e18, "N(0.35) should be approximately 0.6368");
        assertApproxEqRel(Nd2, 559600000000000000, 0.1e18, "N(0.15) should be approximately 0.5596");
    }
}
