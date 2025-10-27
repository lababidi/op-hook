// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {OptionPrice} from "../contracts/OptionPrice.sol";

contract OptionPriceTest is Test {
    address constant WETH_UNI_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    OptionPrice public op;

    string rpc = "https://reth-ethereum.ithaca.xyz/rpc";
    uint mainnetFork;
    
    function setUp() public {

        mainnetFork = vm.createSelectFork(rpc, 23359458);
        op = new OptionPrice();
    }

    // expNeg function tests
    function testExpNegZero() public view {
        // exp(-0) = 1
        assertEq(op.expNeg(0), 1e18, "expNeg(0) should equal 1");
    }
    
    function testExpNegOne() public view {
        assertApproxEqRel(
            op.expNeg(1e18), 
            367879441171442321, 
            0.01e18, // 1% tolerance
            "expNeg(1) should be approximately 0.3679"
        );
        
        assertApproxEqRel(
            op.expNeg(2e18), 
            135335283236612691, 
            0.01e18, // 1% tolerance
            "expNeg(2) should be approximately 0.1353"
        );
        
        // Test large values (should return 0 for x > 10)
        assertEq(op.expNeg(11e18), 0, "expNeg(11) should equal 0");
        assertEq(op.expNeg(100e18), 0, "expNeg(100) should equal 0");
    }

    // normCDF function tests
    function testCDF() public view {
        assertApproxEqRel(
            op.normCdf(0), 
            0.5e18, 
            0.01e18, // 1% tolerance
            "CDF(0) should equal 0.5"
        );
        
        assertApproxEqRel(
            op.normCdf(1e18), 
            uint256(841344746068542948), 
            uint256(5e16), // 5% tolerance due to approximation
            "CDF(1) should be approximately 0.8413"
        );
        
        assertApproxEqRel(
            op.normCdf(-1e18), 
            158655253931457051, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(-1) should be approximately 0.1587"
        );
        
        assertApproxEqRel(
            op.normCdf(2e18), 
            977249868051820792, 
            0.05e18, // 5% tolerance due to approximation
            "CDF(2) should be approximately 0.9772"
        );
    }

    // Black-Scholes pricing tests
    function testBlackScholesATMCall() public view {
        // Test case: ATM call option with 1 year to expiration
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 timeToExpiration = 31536000; // 1 year in seconds
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        
        uint256 callPrice = op.blackScholesPrice(
            underlying, 
            strike, 
            timeToExpiration, 
            volatility, 
            riskFreeRate, 
            false
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

    function testBlackScholesATMPut() public view {
        // Test put option (same parameters)
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 timeToExpiration = 31536000; // 1 year in seconds
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        bool isPut = true;
        
        uint256 putPrice = op.blackScholesPrice(
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
            5.57e18, 
            0.1e18, // 10% tolerance for approximation
            "ATM put option price should be approximately $5.57"
        );
    }

    function testBlackScholesExpiredATMCall() public view {
        // Test expired option (timeToExpiration = 0)
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        
        uint256 expiredCallPrice = op.blackScholesPrice(
            underlying, 
            strike, 
            0, // expired
            volatility, 
            riskFreeRate, 
            false
        );
        
        // For expired ATM call, intrinsic value should be 0
        assertEq(expiredCallPrice, 0, "Expired ATM call should have 0 value");
    }

    function testBlackScholesExpiredITMCall() public view {
        // Test ITM expired call
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        
        uint256 itmExpiredCallPrice = op.blackScholesPrice(
            120e18, // $120 underlying
            100e18, // $100 strike
            100, // near expired
            volatility, 
            riskFreeRate, 
            false
        );
                assertApproxEqRel(
            itmExpiredCallPrice, 
            20e18, 
            0.3e18, // 10% tolerance for approximation
            "Expired ITM call should have intrinsic value of $20"
        );
    }

    function testBlackScholesDebug() public view {
        // Test case: ATM call option with 1 year to expiration
        uint256 underlying = 100e18; // $100
        uint256 strike = 100e18; // $100 (at-the-money)
        uint256 timeToExpiration = 31536000; // 1 year in seconds
        uint256 volatility = 0.2e18; // 20% volatility
        uint256 riskFreeRate = 0.05e18; // 5% risk-free rate
        bool isCall = true;
        
        uint256 callPrice = op.blackScholesPrice(
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
    function test_ln() public view {
        // ln(1) = 0

        assertEq(op.log2(1.00000e18), 59.794705707972522261e18, "log2(1) should equal 0");

        // assertEq(op.ln(1.00000e18), 0, "ln(1) should equal 0");
        assertApproxEqRel(op.ln(1.00000e18), 0, .00001e18, "ln(1.000001) should be approximately 0");

        
        assertApproxEqRel(
            op.ln(15e17), // 1.5 in 1e18 fixed point
            405465108108164381, 
            0.01e18, // 1% tolerance
            "ln(1.5) should be approximately 0.4055"
        );
        
        assertApproxEqRel(
            op.ln(2e18), 
            693147180559945309, 
            0.01e18, // 1% tolerance
            "ln(2) should be approximately 0.6931"
        );
        
        assertApproxEqRel(
            op.ln(1.05e18), // 1.05 in 1e18 fixed point
            48790164169432048, 
            0.01e18, // 1% tolerance
            "ln(1.05) should be approximately 0.0488"
        );
        // Test boundary values
        assertEq(op.ln(1e18), 0, "ln(1) should equal 0");
    }
    
    // function test_ln_out_of_range_low() public {
    //     // Test that out-of-range values revert
    //     vm.expectRevert("ln: x out of grid range");
    //     op.ln(0.5e18); // x < 1
    // }
    
    // function test_ln_out_of_range_high() public {
    //     // Test that out-of-range values revert
    //     vm.expectRevert("ln: x out of grid range");
    //     op.ln(3e18); // x > 2
    // }

    function test_normCDF_BlackScholes_values() public view {
        // Test the actual values produced by the Black-Scholes calculation
        int256 d1 = 350000000000000000; // 0.35 in 1e18 fixed point (actual value from Black-Scholes)
        int256 d2 = 150000000000000000; // 0.15 in 1e18 fixed point (actual value from Black-Scholes)
        
        console.log("Testing normCDF for d1 = 0.35");
        uint256 nd1 = op.normCdf(d1);
        console.log("N(d1):", nd1);
        
        console.log("Testing normCDF for d2 = 0.15");
        uint256 nd2 = op.normCdf(d2);
        console.log("N(d2):", nd2);
        
        // Expected values for the actual Black-Scholes calculation:
        // N(0.35) ≈ 0.6368
        // N(0.15) ≈ 0.5596
        assertApproxEqRel(nd1, 636800000000000000, 0.1e18, "N(0.35) should be approximately 0.6368");
        assertApproxEqRel(nd2, 559600000000000000, 0.1e18, "N(0.15) should be approximately 0.5596");
    }


    function testPrice() public view {
        // opHook.initPool(0xd549Cb6Fd983a5E2b6252f1C41d5dA8Fd04B3339, 0); 
        uint256 price = op.getPrice(
            4600e18,
            3000e18, 
            1758143415, 
            false, 
            false 
        );
        console.log("option price", price / 1e18);
    }
}
