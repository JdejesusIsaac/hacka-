// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import "./interface.sol";
import "../src/IPool.sol";


import "./asset.sol";

//interface IWeth is IERC20  {
 //   function deposit() external payable;
 //   function withdraw(uint wad) external;
  //  function balanceOf(address) external view returns (uint);
  //  function approve(address guy, uint wad) external returns (bool);
//}


//contract VaultTest is Test {
 //       IWeth public  weth;
        
  //      MockERC20 mockAsset;
 //       IPool mockAave;
       
//
 //        Vault vault;
   // address alice = address(0x1);
 //   address alice = address(1234);
    //0x75257671a98Eb7D194457d5e384c30BBd804b313


 //   function setUp() public {
 //      mockAsset = new MockERC20();
 //     mockAave =  IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
      
       
 //      
  //     weth = IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  //      
   //     vault = new Vault(mockAsset, "Vault", "VAULT");

       //uint balBefore = weth.balanceOf(address(this));
     // console.log("balance Before", balBefore);
    // weth.deposit{value: 1000}();
    // uint balAfter = weth.balanceOf(address(this));
   //  console.log("balance After", balAfter);
       

    //  mockAsset.mint(address(this), 1000);
       
  //   mockAsset.approve(address(vault), 1000);
        
        
        

 //     console.log("1000 share token is equal to", 1000 / vault.convertToShares(1));

      // vault._deposit(1000, address(this));
    

  
        
        
        
        //fork mainnet at current block

  //  }

 //   function test_DepositWeth() public {
 //       uint balBefore = weth.balanceOf(address(this));
 //       console.log("balance Before", balBefore);
 //       weth.deposit{value: 1000}();
 //       uint balAfter = weth.balanceOf(address(this));
 //       weth.approve(address(vault), 1000);
        
//        console.log("balance After", balAfter);
//    }

    

  

    
    //  function test_withdrawFromAave() public {
    //    uint startAt = block.timestamp;
        // advancing time to one year
   //      vm.warp(startAt + 365 days);
    //    vault.withdrawFromAave(address(weth), 100);
        
  //  }


    

    
   // function test_depositTotal() public {
  //     assertEq(vault.totalAssets(), 1000, "Incorrect total assets after deposit");
 //  }

    

    //function test_withdraw() public {
    //    vault._withdraw(100, address(this));
   //     assertEq(vault.totalAssets(), 900, "Incorrect total assets after withdraw");
  //  }

   
   
    
//}

    

    



    



     

