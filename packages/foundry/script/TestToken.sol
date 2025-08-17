// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";





contract TestERC20 is IERC20 {
            string public name;
            string public symbol;
            uint8 public decimals = 18;
            uint256 public override totalSupply;
            mapping(address => uint256) public override balanceOf;
            mapping(address => mapping(address => uint256)) public override allowance;

            constructor(string memory _name, string memory _symbol) {
                name = _name;
                symbol = _symbol;
            }

            function transfer(address to, uint256 amount) public override returns (bool) {
                require(balanceOf[msg.sender] >= amount, "insufficient");
                balanceOf[msg.sender] -= amount;
                balanceOf[to] += amount;
                emit Transfer(msg.sender, to, amount);
                return true;
            }

            function approve(address spender, uint256 amount) public override returns (bool) {
                allowance[msg.sender][spender] = amount;
                emit Approval(msg.sender, spender, amount);
                return true;
            }

            function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
                require(balanceOf[from] >= amount, "insufficient");
                require(allowance[from][msg.sender] >= amount, "not allowed");
                allowance[from][msg.sender] -= amount;
                balanceOf[from] -= amount;
                balanceOf[to] += amount;
                emit Transfer(from, to, amount);
                return true;
            }

            function mint(address to, uint256 amount) public {
                balanceOf[to] += amount;
                totalSupply += amount;
                emit Transfer(address(0), to, amount);
            }

        }
