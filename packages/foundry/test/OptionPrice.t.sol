// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {OptionPrice} from "../contracts/OptionPrice.sol";

// Test contract that inherits from OptionPrice to access internal functions
contract TestOptionPrice is OptionPrice {
    // Wrapper functions to expose internal functions for testing
    function testExpNeg(uint256 x) public pure returns (uint256) {
        return expNeg(x);
    }
    
    function testNormCDF(int256 x) public pure returns (uint256) {
        return normCDF(x);
    }
    
    function testLn(uint256 x) public pure returns (int256) {
        return ln(x);
    }
}

contract OptionPriceTest is Test {
    TestOptionPrice public optionPrice;

    function setUp() public {
        optionPrice = new TestOptionPrice();
    }

    function test_expNeg() public view {
        // Test expNeg function with various inputs
        // exp(-0) = 1
        assertEq(optionPrice.testExpNeg(0), 1e18, "expNeg(0) should equal 1");
        
        // exp(-1) ≈ 0.3678794411714423215955237701614608674458111310317678345078368016
        // Using 1e18 fixed point: 367879441171442321
        assertApproxEqRel(
            optionPrice.testExpNeg(1e18), 
            367879441171442321, 
            0.01e18, // 1% tolerance
            "expNeg(1) should be approximately 0.3679"
        );
        
        // exp(-2) ≈ 0.1353352832366126918939994949724844034076315459095758814681588726
        // Using 1e18 fixed point: 135335283236612691
        assertApproxEqRel(
            optionPrice.testExpNeg(2e18), 
            135335283236612691, 
            0.01e18, // 1% tolerance
            "expNeg(2) should be approximately 0.1353"
        );
        
        // Test large values (should return 0 for x > 10)
        assertEq(optionPrice.testExpNeg(11e18), 0, "expNeg(11) should equal 0");
        assertEq(optionPrice.testExpNeg(100e18), 0, "expNeg(100) should equal 0");
    }

    function test_CDF() public view {
        // Test normCDF function with various inputs
        // CDF(0) = 0.5
        assertApproxEqRel(
            optionPrice.testNormCDF(0), 
            0.5e18, 
            0.01e18, // 1% tolerance
            "CDF(0) should equal 0.5"
        );
        
        // CDF(1) ≈ 0.841344746068542948585232545632236508569979607683073846018840
        // Using 1e18 fixed point: 841344746068542948
        assertApproxEqRel(
            optionPrice.testNormCDF(1e18), 
            841344746068542948, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(1) should be approximately 0.8413"
        );
        
        // CDF(-1) ≈ 0.158655253931457051414767454367763491430020392316926153981160
        // Using 1e18 fixed point: 158655253931457051
        assertApproxEqRel(
            optionPrice.testNormCDF(-1e18), 
            158655253931457051, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(-1) should be approximately 0.1587"
        );
        
        // CDF(2) ≈ 0.977249868051820792829203194655283100470870641557131167191311
        // Using 1e18 fixed point: 977249868051820792
        assertApproxEqRel(
            optionPrice.testNormCDF(2e18), 
            977249868051820792, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(2) should be approximately 0.9772"
        );
    }

    function test_BlackScholes() public view {
        // Test Black-Scholes pricing with known values
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
        
        // Test put option (same parameters)
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
        
        // Test expired option (timeToExpiration = 0)
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
        
        // Test ITM expired call
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

    function test_ln() public {
        // Test ln function with various inputs
        // ln(1) = 0
        assertEq(optionPrice.testLn(1e18), 0, "ln(1) should equal 0");
        
        // ln(1.5) ≈ 0.405465108108164381978013115464349136571990423462494197614014
        // Using 1e18 fixed point: 405465108108164381
        assertApproxEqRel(
            optionPrice.testLn(15e17), // 1.5 in 1e18 fixed point
            405465108108164381, 
            0.01e18, // 1% tolerance
            "ln(1.5) should be approximately 0.4055"
        );
        
        // ln(2) ≈ 0.693147180559945309417232121458176568075500134360255254120680
        // Using 1e18 fixed point: 693147180559945309
        assertApproxEqRel(
            optionPrice.testLn(2e18), 
            693147180559945309, 
            0.01e18, // 1% tolerance
            "ln(2) should be approximately 0.6931"
        );
        
        // Test edge cases
        // ln(1.05) ≈ 0.048790164169432048
        assertApproxEqRel(
            optionPrice.testLn(105e16), // 1.05 in 1e18 fixed point
            48790164169432048, 
            0.01e18, // 1% tolerance
            "ln(1.05) should be approximately 0.0488"
        );
        
        // Test boundary values
        assertEq(optionPrice.testLn(1e18), 0, "ln(1) should equal 0");
        assertEq(optionPrice.testLn(2e18), 693147180559945728, "ln(2) should equal grid value");
        
        // Test that out-of-range values revert
        vm.expectRevert("ln: x out of grid range");
        optionPrice.testLn(0.5e18); // x < 1
        
        vm.expectRevert("ln: x out of grid range");
        optionPrice.testLn(3e18); // x > 2
    }
}
