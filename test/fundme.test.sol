// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";

contract fundMeTest is Test {
    FundMe fundMe;

    function setUp() external {
        fundMe = new FundMe();
    }

    function testMinimumDollarIsFive()public {
        assertEq(fundMe.MINIMUM_USD(), 6e18);
    }

}