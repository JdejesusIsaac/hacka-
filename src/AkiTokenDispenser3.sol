// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interface2.sol";

import {Ownable} from "./Ownable.sol";

abstract contract AkiTokenDispenser3 is Ownable  {
    IERC20 public rewardToken; // The ERC-20 token used for the reward pool
    uint256 public rewardPoolBalance; // Balance of the token in the reward pool

    bool public claimingEnabled = false; // Variable to control whether addresses can claim tokens

    struct UserRewardInfo {
        uint256 shares;
        bool hasClaimedReward;
        uint256 claimedRewardAmount;
    }

    // Mapping to keep track of UserRewardInfo for each user
    mapping(address => UserRewardInfo) public userRewardInfo;

    uint256 public totalShares; // Total shares assigned to all reward winners

    uint256 public winnersClaimed; // Number of winners who have claimed their rewards
    uint256 public winnersNotClaimed; // Number of winners who have not claimed their rewards

    event rewardClaimed(address winner, uint256 sharesClaimed, uint256 rewardClaimed, uint256 totalSharesLeft, uint256 rewardPoolLeft);

    modifier validRewardToken() {
        require(address(rewardToken) != address(0), "Reward token not set");
        _;
    }

    // Constructor sets the initial owner and reward token
    constructor(address _rewardToken) {
        require(_rewardToken != address(0), "Invalid token address");
        rewardToken = IERC20(_rewardToken);
        transferOwnership(msg.sender); // Set the contract creator as the owner
    }

    // Function to set the number of shares for an address (for reward winners)
    function setShares(address _address, uint256 _shares) public onlyOwner {
        require(_shares >= 0, "Shares must be non-negative");
        
        uint256 previousShares = userRewardInfo[_address].shares;

        // Deduct previous shares and add new shares
        totalShares = totalShares - previousShares + _shares;

        // Increment the number of winners not claimed if the user has not claimed rewards before
        if (previousShares == 0) {
            winnersNotClaimed++;
        }

        userRewardInfo[_address].shares = _shares;
    }

    // Function to batch set shares for multiple addresses (for reward winners)
    function batchSetShares(address[] calldata _addresses, uint256[] calldata _shares) external onlyOwner {
        require(_addresses.length == _shares.length, "Array lengths must match");
        for (uint256 i = 0; i < _addresses.length; i++) {
            setShares(_addresses[i], _shares[i]);
        }
    }

    // Function to deposit tokens into the reward pool
    function depositTokensIntoPool(uint256 _amount) external onlyOwner validRewardToken {
        require(_amount > 0, "Deposit amount must be greater than 0");
        rewardPoolBalance += _amount;
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    // Function to allow the contract owner to enable or disable claiming
    function setClaimingStatus(bool _status) external onlyOwner {
        claimingEnabled = _status;
    }

    // Function to allow reward winners to claim their share of tokens
    // Function to allow reward winners to claim their share of tokens
    function claimTokens() external validRewardToken {
        require(claimingEnabled, "Claiming is not enabled");
        require(userRewardInfo[msg.sender].shares > 0, "No shares for the address");
        require(!userRewardInfo[msg.sender].hasClaimedReward, "Reward already claimed");

        uint256 userShares = userRewardInfo[msg.sender].shares;
        uint256 claimAmount = (rewardPoolBalance * userShares) / totalShares;

        require(claimAmount > 0, "No tokens to claim");

        totalShares -= userShares; // Update total shares
        rewardPoolBalance -= claimAmount; // Subtract the claimed amount from the reward pool
        userRewardInfo[msg.sender].shares = 0; // Clear shares for the address

        // Update claimed rewards information
        userRewardInfo[msg.sender].hasClaimedReward = true;
        userRewardInfo[msg.sender].claimedRewardAmount = claimAmount;

        // Increment the number of winners claimed and decrement the number of winners not claimed
        winnersClaimed++;
        winnersNotClaimed--;

        // Perform the external transfer as the last step
        rewardToken.transfer(msg.sender, claimAmount);

        emit rewardClaimed(
            msg.sender,
            userShares,
            claimAmount,
            totalShares,
            rewardPoolBalance
        );
    }

    // Function to get the number of tokens a reward winner is eligible for
    function getEligibleTokenBalance(address _address) external view returns (uint256) {
        uint256 userShares = userRewardInfo[_address].shares;
        return (rewardPoolBalance * userShares) / totalShares;
    }

    // Function to check if a user has claimed their reward
    function hasUserClaimedReward(address _address) external view returns (bool) {
        return userRewardInfo[_address].hasClaimedReward;
    }

    // Function to get the amount of reward claimed by a user
    function getClaimedRewardAmount(address _address) external view returns (uint256) {
        return userRewardInfo[_address].claimedRewardAmount;
    }

    // Function to withdraw any remaining tokens from the reward pool (onlyOwner)
    function withdrawTokensFromPool(uint256 _amount) external onlyOwner validRewardToken {
        require(rewardPoolBalance >= _amount, "Insufficient balance in the reward pool");
        rewardPoolBalance -= _amount;
        rewardToken.transfer(owner(), _amount);
    }
}