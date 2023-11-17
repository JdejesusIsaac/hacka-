// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMWom is IERC20 {
    function deposit(uint256 _amount) external;
    function convert(uint256 amount) external;
}