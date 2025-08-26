// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
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
    function getPrice(IUniswapV3Pool pool) internal view returns (uint256) {
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

    mapping(address => address) public pool; //we're sticking to USDC for now and WETH

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
        uint256 r,
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

        uint256 Ks = underlying * 1e18 / strike;

        // ln(underlying/strike)
        int256 lnUS = Ks>1e18 ? ln(Ks) : -ln(1e36/Ks);

        // (r + 0.5 * sigma^2) * t
        uint256 halfSigma2 = (volatility * volatility) / (2 * 1e18);
        uint256 mu = ((r + halfSigma2) * t) / 1e18;

        // d1 = (ln(U/S) + (r + 0.5*sigma^2)*t) / (sigma*sqrt(t))
        int256 d1 = (lnUS + int256(mu)) * 1e18 / int256(sigmaSqrtT);

        // d2 = d1 - sigma*sqrt(t)
        int256 d2 = d1 - int256(sigmaSqrtT);

        // N(d1), N(d2)
        uint256 Nd1 = normCDF(d1);
        uint256 Nd2 = normCDF(d2);

        // exp(-r*t)
        uint256 expRT = expNeg(r * t / 1e18);

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
    function ln(uint256 x) public pure returns (int256) {
        // Precomputed ln(x) values for x in [1.0, 2.0] in 0.05 increments, x in 1e18 fixed point
        // x is 1e18 fixed point, valid for x in [1e18, 2e18]
        // grid: x = 1.00, 1.05, 1.10, ..., 2.00 (21 values)
        require(x >= 1e18 && x <= 2e18, "ln: x out of grid range");
        int256[21] memory lnGrid = [
            int256(0), 
             48790164169432048,  95310179804324928, 139761942375158816, 
            182321556793954784, 223143551314209920, 262364264467491296, 
            300104592450338304, 336472236621213184, 371563556432483264, 
            405465108108164672, 438254930931155584, 470003629245735936, 
            500775287912489600, 530628251062170688, 559615787935423104, 
            587786664902119424, 615185639090233856, 641853886172395264, 
            667829372575655936, 693147180559945728];
        // Compute index: round((x - 1e18) / 5e16)
        // (x - 1e18) is in [0, 1e18], so divide by 5e16 to get [0,20]
        uint256 idx = uint256((x - 1e18 + 25e15) / 5e16); // +0.025 for rounding
        if (idx > 20) idx = 20;
        return lnGrid[idx];
    }

    // Exponential function e^{-x}, x >= 0 in 1e18 fixed point, returns 1e18 fixed point
    // This is specialized for exp(-x) where x > 0, as used in Black-Scholes
    function expNeg(uint256 x) public pure returns (uint256) {
        if (x>10 *1e18) {
            return 0;
        }
        if (x==0) {
            return 1e18;
        }
        // Use uint64 to match the literal values and avoid type conversion error
        uint64[100] memory expGrid = [
            951229424500713984, 904837418035959552, 860707976425057792, 818730753077981824, 778800783071404928, 
            740818220681717888, 704688089718713472, 670320046035639296, 637628151621773312, 606530659712633472, 
            576949810380486656, 548811636094026368, 522045776761015936, 496585303791409472, 472366552741014656, 
            449328964117221568, 427414931948726656, 406569659740599040, 386741023454501184, 367879441171442304, 
            349937749111155328, 332871083698079552, 316636769379053184, 301194211912202048, 286504796860190048, 
            272531793034012608, 259240260645891520, 246596963941606432, 234570288093797632, 223130160148429792, 
            212247973826743040, 201896517994655392, 192049908620754080, 182683524052734624, 173773943450445088, 
            165298888221586528, 157237166313627616, 149568619222635040, 142274071586513536, 135335283236612704, 
            128734903587804240, 122456428252981904, 116484157773496960, 110803158362333904, 105399224561864336, 
            100258843722803744, 95369162215549616, 90717953289412512, 86293586499370496, 82084998623898800, 
            78081666001153168, 74273578214333872, 70651213060429600, 67205512739749760, 63927861206707568, 
            60810062625217976, 57844320874838456, 55023220056407232, 52339705948432384, 49787068367863944, 
            47358924391140928, 45049202393557800, 42852126867040184, 40762203978366208, 38774207831722008, 
            36883167401240016, 35084354100845024, 33373269960326080, 31745636378067940, 30197383422318500, 
            28724639654239432, 27323722447292560, 25991128778755348, 24723526470339388, 23517745856009108, 
            22370771856165600, 21279736438377168, 20241911445804392, 19254701775386920, 18315638888734180, 
            17422374639493514, 16572675401761254, 15764416484854486, 14995576820477704, 14264233908999256, 
            13568559012200934, 12906812580479872, 12277339903068436, 11678566970395442, 11108996538242306, 
            10567204383852654, 10051835744633586, 9561601930543504, 9095277101695816, 8651695203120634, 
            8229747049020030, 7828377549225767, 7446583070924338, 7083408929052118, 6737946999085467
        ];
        // For x in [0, 10e18], map x to idx in [0,99] for expGrid (step size = 0.1e18)
        // this is actually 0 to 5
        // There are 100 items in expGrid, mapping x in [0, 5e18] to idx in [0,99]
        // Each step is 0.05e18 (5e16)
        uint256 idx = uint256(-1 + int256(x / 5e16)); // 5e16 = 0.05e18, so x in [0, 5e18] maps to idx in [0,99]
        if (idx > 99) idx = 99;
        uint256 expVal = uint256(expGrid[idx]);
        return expVal;

    }
    function abs(int256 x) public pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }

    // Standard normal CDF using lookup table for common values
    function normCDF(int256 x) public pure returns (uint256) {
                if (x >= 0) {
            return normCDFPositive(x);
        } else {
            return 1e18 - normCDFPositive(-x);
        }
    }
    
    function normCDFOld(int256 x) public pure returns (uint256) {
        uint256 x_ = abs(x);
        // rate = 1.67 in 1e18 fixed point
        uint256 rate = 1670000000000000000;
        // Compute -rate * x / 1e18 to keep fixed point math
        uint256 negExponent = ((rate * x_) / 1e18);
        uint256 expVal = expNeg(negExponent); // exp returns 1e18 fixed point
        
        // 1e18 / (1e18 + expVal)
        uint256 rightside = (1e18 * 1e18) / (1e18 + expVal);
        return x>0 ? rightside : 1e18 - rightside;
    }

    function normCDFPositiveUse(int256 x) public pure returns (uint256) {
        if (x >= 0) {
            return normCDFPositive(x);
        } else {
            return 1e18 - normCDFPositive(-x);
        }
    }
    
    function normCDFPositive(int256 x) internal pure returns (uint256) {

        uint64[101] memory table = [500000000000000000, 519938805838372480, 539827837277028992, 559617692370242496, 579259709439102976, 598706325682923648, 617911422188952704, 636830651175619072, 655421741610324224, 673644779712080000, 691462461274013056, 708840313211653632, 725746882249926400, 742153889194135296, 758036347776926976, 773372647623131776, 788144601416603392, 802337456877307648, 815939874653240448, 828943873691518208, 841344746068542976, 853140943624104064, 864333939053617280, 874928064362849792, 884930329778291840, 894350226333144704, 903199515414389760, 911492008562598016, 919243340766228992, 926470740390351744, 933192798731141888, 939429241997940992, 945200708300441984, 950528531966351872, 955434537241457024, 959940843136182912, 964069680887074176, 967843225204386304, 971283440183998208, 974411940478361472, 977249868051820800, 979817784594295552, 982135579437183488, 984222392608909568, 986096552486501376, 987775527344955392, 989275889978324224, 990613294465161472, 991802464075403904, 992857189264728576, 993790334674223872, 994613854045933312, 995338811976281216, 995975411457241728, 996533026196959360, 997020236764945408, 997444869669571968, 997814038545086720, 998134186699616000, 998411130352635136, 998650101968369920, 998855793168977280, 999032396786781696, 999183647687171456, 999312862062084096, 999422974957609216, 999516575857616256, 999595942198135936, 999663070734323200, 999719706723183744, 999767370920964480, 999807384424364288, 999840891409842432, 999868879845579520, 999892200266522624, 999911582714799232, 999927651956074880, 999940941087581056, 999951903655982464, 999960924403402240, 999968328758166912, 999974391183525888, 999979342493087488, 999983376236270336, 999986654250984064, 999989311474225152, 999991460094529024, 999993193123400576, 999994587456092288, 999995706485529984, 999996602326875264, 999997317704220416, 999997887545297536, 999998340324855680, 999998699192546176, 999998982916757504, 999999206671848064, 999999382692627968, 999999520816723328, 999999628932592128, 999999713348428032];

        uint256 index = uint256(x/0.05e18);
        if (index > 100) return 1e18;
        return uint256(table[index]);

    }

    // Square root for 1e18 fixed point, returns 1e18 fixed point
    function sqrt(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


    // Returns the price of the token (18 decimals)
    function getPrice(address token, bool inverse) external view returns (uint256) {
        IOptionToken optionToken = IOptionToken(token);
        uint256 expiration = optionToken.expirationDate();
        uint256 strike = optionToken.strike();
        IERC20 collateral = optionToken.collateral();
        bool optionType = optionToken.isPut();

        uint256 collateralPrice = PriceMath.getPrice(IUniswapV3Pool(pool[address(collateral)]));

        uint256 price = blackScholesPrice(
            collateralPrice, 
            strike, 
            expiration - block.timestamp, 
            0.2 * 1e18, 
            0.05 * 1e18, 
            optionType
            );

        return inverse ? 1e36 / price : price ;
    }


}
