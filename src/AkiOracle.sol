// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AkiOracle is Ownable {
  mapping(string => bytes32) public subToSNARK;
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