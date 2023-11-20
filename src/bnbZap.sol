// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPancakeRouter02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMasterWombat {

    function getAssetPid(address lp) external view returns(uint256);
    
    function depositFor(uint256 pid, uint256 amount, address account) external;

    function deposit(uint256 _pid, uint256 _amount) external returns (uint256, uint256);

    function withdraw(uint256 _pid, uint256 _amount) external returns (uint256, uint256);

    function multiClaim(uint256[] memory _pids) external returns (
        uint256 transfered,
        uint256[] memory amounts,
        uint256[] memory additionalRewards
    );

    function pendingTokens(uint256 _pid, address _user) external view
        returns (
            uint256 pendingRewards,
            IERC20[] memory bonusTokenAddresses,
            string[] memory bonusTokenSymbols,
            uint256[] memory pendingBonusRewards
    );

    function migrate(uint256[] calldata _pids) external;
}

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract zppBnb is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    address public masterWombat;

    struct Pool {
        uint256 pid; // pid on master wombat
        address depositToken; // token to be deposited on wombat
        address lpAddress; // token received after deposit on wombat
        address receiptToken; // token to receive after
        address rewarder;
        address helper;
        address depositTarget;
        bool isActive;
    }
    mapping(address => Pool) public pools;

    mapping(address => address[]) public assetToBonusRewards; // extra rewards for alt pool

    error BonusRewardExisted();

    function addBonusRewardForAsset(
        address _lpToken,
        address _bonusToken
    ) external onlyOwner {
        uint256 length = assetToBonusRewards[_lpToken].length;
        for (uint256 i = 0; i < length; i++) {
            if (assetToBonusRewards[_lpToken][i] == _bonusToken)
                revert BonusRewardExisted();
        }

        assetToBonusRewards[_lpToken].push(_bonusToken);
    }

    function _rewardBeforeBalances(
        address _lpToken
    ) internal view returns (uint256[] memory beforeBalances) {
        address[] memory bonusTokens = assetToBonusRewards[_lpToken];
        uint256 bonusTokensLength = bonusTokens.length;
        beforeBalances = new uint256[](bonusTokensLength);
        for (uint256 i; i < bonusTokensLength; i++) {
            beforeBalances[i] = IERC20(bonusTokens[i]).balanceOf(address(this));
        }
    }

    function _stakeToWombatMaster(
        address _lpToken,
        uint256 _lpAmount
    ) internal {
        Pool storage poolInfo = pools[_lpToken];
        // Approve Transfer to Master Wombat for Staking
        IERC20(_lpToken).safeApprove(masterWombat, _lpAmount);
        IMasterWombat(masterWombat).deposit(poolInfo.pid, _lpAmount);
    }
}

