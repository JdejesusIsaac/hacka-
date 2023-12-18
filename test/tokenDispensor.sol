// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AkiTokenDispenser} from "../src/AkiTokenDispenser.sol";
//import "./interface.sol";
import {MockERC20} from "./asset.sol";

import {IERC20} from "./interface.sol";




address constant usdt = 0x55d398326f99059fF775485246999027B3197955;

contract AkiTokenDispenserTest is Test {
    
    AkiTokenDispenser dispenser;
    
    string uniqueActivityId;
    uint256 numParticipants;
    string activityId = "testActivity";
    



    function setUp() public {
        
        dispenser = new AkiTokenDispenser();
        
        
        MockERC20 mockAsset;
       mockAsset = new MockERC20();
         
         mockAsset.mint(address(this), 1000);
          
          mockAsset.approve(address(dispenser), 1000);
          uint256 paymentAmount = 1 ;
        uniqueActivityId = "SummerChallenge2023";

          dispenser.addPayment(address(mockAsset), paymentAmount, activityId);
          
        
       //address usdt = 0x55d398326f99059fF775485246999027B3197955;
       
       
       
        

        
        
         
    }

     function test_setTokenInfo() public {
        numParticipants = 15000;
        address[] memory participants = new address[](numParticipants);
        uint64[] memory shares = new uint64[](numParticipants);
       
         dispenser.setTokenInfo(uniqueActivityId, participants, shares);

    }

    
   

    

    

    function test_receiveEventRewards_DoSVulnerability() public {
       
        // Measure gas before calling receiveEventRewards
      //  uint256 gasBefore = gasleft();
        // call receiveEventRewards
        string[] memory activityIds = new string[](1);
        activityIds[0] = activityId;

        dispenser.receiveEventRewards(activityIds);
        
       
       // uint256 gasAfter = gasleft();
        
      //  uint256 gasUsed = gasBefore - gasAfter;

        // Log the gas used
     //   console.log("Gas used for receiveEventRewards with many participants:", gasUsed);

        
    }
    
    

 

         
         
    
}