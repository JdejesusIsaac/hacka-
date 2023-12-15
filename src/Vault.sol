// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./ERC4626.sol";
import "./IPool.sol";
import {SafeTransferLib} from "./SafeTransferLib.sol";

contract Vault is ERC4626 {
    using SafeTransferLib for ERC20;
    mapping(address => uint256) public shareHolder;
    address public owner;
    
    constructor(ERC20 _asset, string memory _name, string memory _symbol) ERC4626 (_asset, _name, _symbol){
        owner = msg.sender;
    }

    modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;
}

     

    /**
 * @notice function to deposit assets and receive vault token in exchange
 * @param _assets amount of the asset token
 */

    function _deposit(uint _assets, address _depositer) public {
    // checks that the deposited amount is greater than zero.
    require(_assets > 0, "Deposit less than Zero");
    // calling the deposit function ERC-4626 library to perform all the functionality
    //uint256 shares = previewDeposit(_assets);
    
    deposit(_assets, _depositer);
    // Increase the share of the user
    shareHolder[_depositer] += _assets;
}

// getter function to view the total amount of assets deposited in this vault
// returns total number of assets
function totalAssets() public view override returns (uint256) {
    return asset.balanceOf(address(this));
}


/** 
    }

//  users can redeem their original amount of asset tokens, along with the yield generated by those asset tokens, in exchange for shares or vault tokens
/**
 * @notice Function to allow msg.sender to withdraw their deposit plus accrued interest
 * @param _shares amount of shares the user wants to convert
 * @param _receiver address of the user who will receive the assets
 */
function _withdraw(uint _shares, address _receiver) external  {
    // checks that the deposited amount is greater than zero.
    require(_shares > 0, "withdraw must be greater than Zero");
    require(_receiver == owner, "Not owner");
    // Checks that the _receiver address is not zero.
    require(_receiver != address(0), "Zero Address");
   
    
    // checks that the caller has more shares than they are trying to withdraw.
    require(shareHolder[_receiver] >= _shares, "Not enough shares");
    
    
    
    // Calculate 10% yield on the withdraw amount
    //uint256 percent = (10 * _shares) / 100; + percent;
    // Calculate the total asset amount as the sum of the share amount plus 10% of the share amount.
    uint256 assets = _shares ;
    // calling the redeem function from the ERC-4626 library to perform all the necessary functionality
    shareHolder[_receiver] -= _shares; 
  
    redeem(assets, _receiver, msg.sender);
    // Decrease the share of the user
   // shareHolder[_receiver] -= _shares; // was msg.sender
}

// returns total balance of user
    function totalAssetsOfUser(address _user) public view returns (uint256) {
        return asset.balanceOf(_user);
    }

    function lendOnAave(address aaveV3, uint256 _amount) public onlyOwner {
        require(_amount > 0, "lending  less than Zero");
        asset.safeApprove(aaveV3, _amount);
        IPool(aaveV3).supply(address(asset), _amount, address(this), 0);
    }

    function withdrawFromAave(address aaveV3, uint256 _amount) public onlyOwner {
        require(_amount > 0, "withdraw less than Zero");
        IPool(aaveV3).withdraw(address(asset), _amount, address(this));
    }

    // function to get user account data
    function UserAccountData(address _user, address _aaveV3) public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        return IPool(_aaveV3).getUserAccountData(_user);
    }
     
}