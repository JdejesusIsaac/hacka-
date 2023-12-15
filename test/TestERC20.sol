//SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "./Token.sol";

contract TestERC20 is Token {

    //Storage
    address public mockERC20;//address of the charon contract
    //Events
    event Minted(address _to, uint256 _amount);
    event Burned(address _from, uint256 _amount);

    /**
     * @dev constructor to initialize contract and token
     */
    constructor(string memory _name, string memory _symbol, uint256 decimal) Token(_name,_symbol){
       // mockERC20 = _mockERC20;
    }

    /**
     * @dev allows the charon contract to burn tokens of users
     * @param _from address to burn tokens of
     * @param _amount amount of tokens to burn
     * @return bool of success
     */
    function burn(address _from, uint256 _amount) external returns(bool){
        //require(msg.sender == mockERC20,"caller must be charon");
        _burn(_from, _amount);
        emit Burned(_from,_amount);
        return true;
    }
    
    /**
     * @dev allows the charon contract to mint chd tokens
     * @param _to address to mint tokens to
     * @param _amount amount of tokens to mint
     * @return bool of success
     */
    function mint(address _to, uint256 _amount) external returns(bool){
        //require(msg.sender == mockERC20, "caller must be charon");
        _mint(_to,_amount);
        emit Minted(_to,_amount);
        return true;
    }
}