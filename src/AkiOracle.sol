// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MerkleProof.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

contract AkiOracle  {
  address public owner;
  mapping(string => bytes32) public subToSNARK;

  constructor() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;
  }
  function setSubToSNARK(
    string  calldata subscription,
    bytes32 snark
  ) public onlyOwner { 
    subToSNARK[subscription] = snark;
  }

  
  // Note: leaf shouldn't be bytes32, so we can make sure we prevent preimage attack
  // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3091
  function verify(
    string calldata subscription,
    bytes32[] calldata proof,
    bytes calldata leaf
  ) public view returns (bool) {
    bytes32 snark = subToSNARK[subscription];
    require(
        snark != 0x0,
        "Subscription cannot be empty"
    );
    return MerkleProof.verify(
        proof,
        snark,
        keccak256(leaf)
    );
  }
}