//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../src/shagPie.sol";



contract shagPieTest is Test {

    MasterMagpie shagPie;
    
    address internal initAccount;
    address internal bob;
    address internal alice;

    function setUp() public {

        shagPie = new MasterMagpie();

        initAccount = makeAddr("init");
        
        bob = makeAddr("bob");

        alice = makeAddr("alice");

}

// bob deposits



}



