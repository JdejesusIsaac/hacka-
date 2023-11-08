// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuard } from "./ReentrancyGuard.sol";


contract Vesting is
    
    ReentrancyGuard,
    OwnableUpgradeable
    
{
    using SafeERC20 for IERC20;
    IERC20 public projectToken;
    
    address public padContract;

    

     struct VestingInfo {
        uint256 lowFDVAmount; // amount of low FDV sale phase vested tokens
        uint256 highFDVAmount; // amount of high FDV sale phase vested tokens
        uint256 lowFDVClaimedAmount; // amount of claimed low FDV sale phase vested tokens
        uint256 highFDVClaimedAmount; // amount of claimed high FDV sale phase vested tokens
    }

    mapping(address => VestingInfo) public vestingInfo;

    event VestedTokens(address indexed user, bool isLowFDVedPhase, uint256 amount);
    event padSet(address newLaunchpadAddress);

     error Onlypad();

    error AddressZero();

      constructor() {
        _disableInitializers();
    }

    /* ============ Initializer ============ */
    



      modifier onlypad() {
        if (padContract != msg.sender) revert Onlypad();
        _;
    }

     function setLaunchpad(address _newAddress) external onlyOwner {
        if (_newAddress == address(0)) revert AddressZero();
        padContract = _newAddress;

        emit padSet(_newAddress);
    }

    function vestTokens(
        bool isLowFDVedVesting,
        uint256 amount,
        address vestFor
    ) external onlypad nonReentrant {
        projectToken.safeTransferFrom(msg.sender, address(this), amount);

        _processVesting(isLowFDVedVesting, amount, vestFor);
        emit VestedTokens(vestFor, isLowFDVedVesting, amount);
    }


function _processVesting(bool isLowFDVedVesting, uint256 amount, address vestFor) internal {
        if (isLowFDVedVesting) {
            vestingInfo[vestFor].lowFDVAmount = amount;
        } else {
            vestingInfo[vestFor].highFDVAmount = amount;
        }
    }


   


   

   
   

}


    

   





