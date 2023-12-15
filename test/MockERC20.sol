//SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./TestERC20.sol";

/**
 @title MockERC20
 @dev mock token contract to allow minting and burning for testing
**/  
contract MockERC20 is TestERC20{

    constructor(string memory _name, string memory _symbol, uint256 decimal) TestERC20(_name,_symbol, decimal){
    }

    function testmint(address account, uint256 amount) external virtual {
        _mint(account,amount);
    }

    function testburn(address account, uint256 amount) external virtual {
        _burn(account,amount);
    }
}