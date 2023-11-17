// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface ISimpleHelper {
    function depositFor(uint256 _amount, address _for) external;
}