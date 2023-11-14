
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';


/// @title MGP
/// @author Magpie Team
contract MGP is ERC20('Magpie Token', 'MGP')  {
    constructor(address _receipient, uint256 _totalSupply) {
        _mint(_receipient, _totalSupply);
    }
}