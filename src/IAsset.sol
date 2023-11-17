// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
interface IAsset is IERC20 {
    function cash() external view returns (uint120);
    function liability() external view returns (uint120);
}
