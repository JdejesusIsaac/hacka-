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

    uint256 public vestingStartTime; // Vesting period start time

    uint256 public LOW_FDV_VESTING_DURATION; // Vesting period for Low FDV Vesting Phase
    uint256 public HIGH_FDV_VESTING_DURATION; // Vesting period for Public Vesting Phase


    

     struct VestingInfo {
        uint256 lowFDVAmount; // amount of low FDV sale phase vested tokens
        uint256 highFDVAmount; // amount of high FDV sale phase vested tokens
        uint256 lowFDVClaimedAmount; // amount of claimed low FDV sale phase vested tokens
        uint256 highFDVClaimedAmount; // amount of claimed high FDV sale phase vested tokens
    }

    mapping(address => VestingInfo) public vestingInfo;

    event VestedTokens(address indexed user, bool isLowFDVedPhase, uint256 amount);
    event padSet(address newLaunchpadAddress);

    event VestingStartTimeSet(uint256 newStartTime);

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

     function configLaunchpadVesting(
        address _projectToken,
        uint256 _lowFDVVestingDuration,
        uint256 _highFDVVestingDuration
    ) external onlyOwner {
        if (address(_projectToken) == address(0)) revert AddressZero();
        projectToken = IERC20(_projectToken);

        LOW_FDV_VESTING_DURATION = _lowFDVVestingDuration;
        HIGH_FDV_VESTING_DURATION = _highFDVVestingDuration;
    }

    function configpadVesting(
    address _projectToken,
    uint256 _lowFDVVestingDuration,
    uint256 _highFDVVestingDuration
) external onlyOwner {
    require(vestingStartTime == 0, "Vesting has already started");
    if (address(_projectToken) == address(0)) revert AddressZero();
    projectToken = IERC20(_projectToken);

    LOW_FDV_VESTING_DURATION = _lowFDVVestingDuration;
    HIGH_FDV_VESTING_DURATION = _highFDVVestingDuration;
}

    function getClaimable(
        address account
    ) external view returns (uint256 lowFDVAmount, uint256 highFDVAmount) {
        VestingInfo storage vestingData = vestingInfo[account];
        uint256 currentTime = _currentBlockTimestamp();

        if (
            vestingData.lowFDVAmount != 0 &&
            vestingData.lowFDVAmount > vestingData.lowFDVClaimedAmount
        ) {
            uint256 endTime = vestingStartTime + LOW_FDV_VESTING_DURATION;
            if (currentTime < endTime) {
                lowFDVAmount =
                    ((currentTime - vestingStartTime) * vestingData.lowFDVAmount) /
                    LOW_FDV_VESTING_DURATION;
            } else {
                lowFDVAmount = vestingData.lowFDVAmount;
            }
            lowFDVAmount -= vestingData.lowFDVClaimedAmount;
        }

        if (
            vestingData.highFDVAmount != 0 &&
            vestingData.highFDVAmount > vestingData.highFDVClaimedAmount
        ) {
            uint256 endTime = vestingStartTime + HIGH_FDV_VESTING_DURATION;
            if (currentTime < endTime) {
                highFDVAmount =
                    ((currentTime - vestingStartTime) * vestingData.highFDVAmount) /
                    HIGH_FDV_VESTING_DURATION;
            } else {
                highFDVAmount = vestingData.highFDVAmount;
            }
            highFDVAmount -= vestingData.highFDVClaimedAmount;
        }
    }

    /// @dev claim vested tokens
    function claim() external nonReentrant {
        (uint256 lowFDVAmount, uint256 highFDVAmount) = this.getClaimable(msg.sender);

        if (lowFDVAmount + highFDVAmount > 0) {
            VestingInfo storage vestingData = vestingInfo[msg.sender];

            vestingData.lowFDVClaimedAmount = vestingData.lowFDVClaimedAmount + lowFDVAmount;
            vestingData.highFDVClaimedAmount = vestingData.highFDVClaimedAmount + highFDVAmount;
            projectToken.safeTransfer(msg.sender, lowFDVAmount + highFDVAmount);
        }
    }

    /// @dev Setting start time for vesting period
    function setVestingStartTime(uint256 _startTime) external onlypad {
        vestingStartTime = _startTime;
        emit VestingStartTimeSet(_startTime);
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

     function _currentBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}









    

   





