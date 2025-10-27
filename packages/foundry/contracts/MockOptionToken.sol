// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IOptionToken} from "../contracts/IOptionToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPermit2} from "../contracts/IPermit2.sol";


// Import the mock option token from the fork test file
contract MockOptionToken is ERC20, IOptionToken {
    uint256 private _expirationDate;
    uint256 private _strike;
    bool private _isPut;
    IERC20 private _collateral;
    IERC20 private _consideration;
    address private _permit2;
    bool private _initialized;
    
    constructor(string memory name_, string memory symbol_, address collateral_, address consideration_, uint256 expirationDate_, uint256 strike_, bool isPut_) ERC20(name_, symbol_) {
        _expirationDate = expirationDate_;
        _strike = strike_;
        _isPut = isPut_;
        _collateral = IERC20(collateral_);
        _consideration = IERC20(consideration_);
        _initialized = true;
    }
    
    function setParams(address collateral_, address consideration_) external {
        _collateral = IERC20(collateral_);
        _consideration = IERC20(consideration_);
    }
    
    function PERMIT2() external view returns (address) { return _permit2; }
    function expirationDate() external view returns (uint256) { return _expirationDate; }
    function strike() external view returns (uint256) { return _strike; }
    function STRIKE_DECIMALS() external pure returns (uint256) { return 18; }
    function isPut() external view returns (bool) { return _isPut; }
    function collateral() external view returns (IERC20) { return _collateral; }
    function consideration() external view returns (IERC20) { return _consideration; }
    function initialized() external view returns (bool) { return _initialized; }
    
    function toConsideration(uint256 amount) external pure returns (uint256) { return amount; }
    
    function init(
        string memory,
        string memory,
        address collateral_,
        address consideration_,
        uint256 expirationDate_,
        uint256 strike_,
        bool isPut_
    ) external {
        _collateral = IERC20(collateral_);
        _consideration = IERC20(consideration_);
        _expirationDate = expirationDate_;
        _strike = strike_;
        _isPut = isPut_;
        _initialized = true;
    }
    
    function name() public view override(ERC20, IOptionToken) returns (string memory) {
        return ERC20.name();
    }
    
    function symbol() public view override(ERC20, IOptionToken) returns (string memory) {
        return ERC20.symbol();
    }
    
    function collateralData() external pure returns (TokenData memory) {
        return TokenData("WETH", "WETH", 18);
    }
    
    function considerationData() external pure returns (TokenData memory) {
        return TokenData("USDC", "USDC", 6);
    }
    
    function mint(IPermit2.PermitTransferFrom calldata, IPermit2.SignatureTransferDetails calldata, bytes calldata) external {
        _mint(msg.sender, 1000 * 1e18);
    }
    
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
    
    function exercise(IPermit2.PermitTransferFrom calldata, IPermit2.SignatureTransferDetails calldata, bytes calldata) external {
        // Mock implementation
    }
    
    function redeem(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}


