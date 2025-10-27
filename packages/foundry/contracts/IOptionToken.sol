// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPermit2 } from "./IPermit2.sol";


interface IOptionToken is IERC20 {
    // Structs
    struct TokenData {
        string name;
        string symbol;
        uint8 decimals;
    }

    // Events
    event Mint(address indexed optionToken, address indexed minter, uint256 amount);
    event Exercise(address indexed optionToken, address indexed exerciser, uint256 amount);

    // Errors
    error ContractNotExpired();
    error ContractExpired();
    error InsufficientBalance();
    error InvalidValue();

    // State variables
    function PERMIT2() external view returns (address);
    function expirationDate() external view returns (uint256);
    function strike() external view returns (uint256);
    function STRIKE_DECIMALS() external view returns (uint256);
    function isPut() external view returns (bool);
    function collateral() external view returns (IERC20);
    function consideration() external view returns (IERC20);
    function initialized() external view returns (bool);

    // Functions
    function toConsideration(uint256 amount) external view returns (uint256);
    
    function init(
        string memory name_,
        string memory symbol_,
        address collateral_,
        address consideration_,
        uint256 expirationDate_,
        uint256 strike_,
        bool isPut_
    ) external;
    
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    
    function collateralData() external view returns (TokenData memory);
    function considerationData() external view returns (TokenData memory);

    // Option operations
    function mint(
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external;

    // Option operations
    function mint(
        uint256 amount
    ) external;

    function exercise(
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external;

    function redeem(uint256 amount) external;
}
