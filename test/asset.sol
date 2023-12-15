// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../src/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("USDC", "usdc", 18) {}

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

    
}