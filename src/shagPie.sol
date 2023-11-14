// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import { ReentrancyGuard } from "./ReentrancyGuard.sol";
import "./Mgp.sol";
import "./IBaseRewardPool.sol";
import "./ILocker.sol";


contract MasterMagpie is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuard
    
    
{
    using SafeERC20 for IERC20;



    /* ============ Structs ============ */

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many staking tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 available; // in case of locking
        //
        // We do some fancy math here. Basically, any point in time, the amount of MGPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accMGPPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws staking tokens to a pool. Here's what happens:
        //   1. The pool's `accMGPPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        address stakingToken; // Address of staking token contract to be staked.
        uint256 allocPoint; // How many allocation points assigned to this pool. MGPs to distribute per second.
        uint256 lastRewardTimestamp; // Last timestamp that MGPs distribution occurs.
        uint256 accMGPPerShare; // Accumulated MGPs per share, times 1e12. See below.
        address rewarder;
        address helper;
        bool helperNeedsHarvest;
    }

    /* ============ State Variables ============ */

    // The MGP TOKEN!
    MGP public mgp;

    ILocker public vlmgp;

    ILocker public mWomSV;

    

    // MGP tokens created per second.
    uint256 public mgpPerSec;

    // Registered staking tokens
    address[] public registeredToken;
    // Info of each pool.
    mapping(address => PoolInfo) public tokenToPoolInfo;
    // Set of all staking tokens that have been added as pools
    mapping(address => bool) private openPools;
    // Info of each user that stakes staking tokens [_staking][_account]
    mapping(address => mapping(address => UserInfo)) private userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The timestamp when MGP mining starts.
    uint256 public startTimestamp;

    mapping(address => bool) public PoolManagers;

    address public compounder;

    /* ==== variable added for first upgrade === */

    mapping(address => bool) public MPGRewardPool; // pools that emit MGP otherwise, vlMGP

    /* ==== variable added for second upgrade === */

    mapping(address => mapping(address => uint256)) public unClaimedMgp; // unclaimed mgp reward before lastRewardTimestamp
    mapping(address => address) public legacyRewarder; // old rewarder

    /* ==== variable added for third upgrade === */

    address public referral;

    /* ==== variable added for fourth upgrade === */

  

    /* ==== variable added for fifth upgrade === */

    address[] public AllocationManagers;

    /* ============ Events ============ */

    event Add(
        uint256 _allocPoint,
        address indexed _stakingToken,
        IBaseRewardPool indexed _rewarder
    );
    event Set(
        address indexed _stakingToken,
        uint256 _allocPoint,
        IBaseRewardPool indexed _rewarder
    );
    event Deposit(
        address indexed _user,
        address indexed _stakingToken,
        uint256 _amount
    );
    event Withdraw(
        address indexed _user,
        address indexed _stakingToken,
        uint256 _amount
    );
    event UpdatePool(
        address indexed _stakingToken,
        uint256 _lastRewardTimestamp,
        uint256 _lpSupply,
        uint256 _accMGPPerShare
    );

    event DepositNotAvailable(
        address indexed _user,
        address indexed _stakingToken,
        uint256 _amount
    );

    event MGPSet(address _mgp);

    error OnlyPoolManager();
    error OnlyPoolHelper();
    error OnlyActivePool();
    error PoolExsisted();
    error InvalidStakingToken();
    error WithdrawAmountExceedsStaked();
    error UnlockAmountExceedsLocked();
    error MustBeContractOrZero();
    error OnlyCompounder();
    error OnlyLocker();
    error MGPsetAlready();
    error MustBeContract();
    error LengthMismatch();
    error OnlyWhiteListedAllocUpdator();
    error MustNotBeZero();
    error IndexOutOfBound();


    function __MasterMagpie_init(
        address _mgp,
        uint256 _mgpPerSec,
        uint256 _startTimestamp
    ) public initializer {
        
        mgp = MGP(_mgp);
        mgpPerSec = _mgpPerSec;
        startTimestamp = _startTimestamp;
        totalAllocPoint = 0;
        PoolManagers[owner()] = true;
    }


     modifier _onlyPoolManager() {
        if (!PoolManagers[msg.sender]) revert OnlyPoolManager();
        _;
    }

    modifier _onlyWhiteListed() {
        bool isCallerWhiteListed = false;
        for (uint i; i < AllocationManagers.length; i++) {
            if (AllocationManagers[i] == msg.sender) {
                isCallerWhiteListed = true;
                break;
            }
        }
        if (isCallerWhiteListed == true || owner() == msg.sender) {
            _;
        } else {
            revert OnlyWhiteListedAllocUpdator();
        }
    }

    modifier _onlyPoolHelper(address _stakedToken) {
        if (msg.sender != tokenToPoolInfo[_stakedToken].helper)
            revert OnlyPoolHelper();
        _;
    }

     /* ============ External Functions ============ */

    /// @notice Deposits staking token to the pool, updates pool and distributes rewards
    /// @param _stakingToken Staking token of the pool
    /// @param _amount Amount to deposit to the pool
    function deposit(
        address _stakingToken,
        uint256 _amount
    ) external  nonReentrant {
        _deposit(_stakingToken, msg.sender, _amount, false);
    }

    /// @notice Withdraw staking tokens from Master Mgapie.
    /// @param _stakingToken Staking token of the pool
    /// @param _amount amount to withdraw
    function withdraw(
        address _stakingToken,
        uint256 _amount
    ) external  nonReentrant {
        _withdraw(_stakingToken, msg.sender, _amount, false);
    }

    /// @notice Deposit staking tokens to Master Magpie. Can only be called by pool helper
    /// @param _stakingToken Staking token of the pool
    /// @param _amount Amount to deposit
    /// @param _for Address of the user the pool helper is depositing for, and also harvested reward will be sent to
    function depositFor(
        address _stakingToken,
        uint256 _amount,
        address _for
    ) external  _onlyPoolHelper(_stakingToken) nonReentrant {
        _deposit(_stakingToken, _for, _amount, false);
    }

    /// @notice Withdraw staking tokens from Mastser Magpie for a specific user. Can only be called by pool helper
    /// @param _stakingToken Staking token of the pool
    /// @param _amount amount to withdraw
    /// @param _for address of the user to withdraw for, and also harvested reward will be sent to
    function withdrawFor(
        address _stakingToken,
        uint256 _amount,
        address _for
    ) external  _onlyPoolHelper(_stakingToken) nonReentrant {
        _withdraw(_stakingToken, _for, _amount, false);
    }

     /// @notice internal function to deal with deposit staking token
    function _deposit(
        address _stakingToken,
        address _account,
        uint256 _amount,
        bool _isVlmgp
    ) internal {
        updatePool(_stakingToken);

        PoolInfo storage pool = tokenToPoolInfo[_stakingToken];
        UserInfo storage user = userInfo[_stakingToken][_account];

        if (user.amount > 0) {
            _harvestMGP(_stakingToken, _account);
        }
        _harvestBaseRewarder(_stakingToken, _account);

        user.amount = user.amount + _amount;
        if (!_isVlmgp) {
            user.available = user.available + _amount;
            IERC20(pool.stakingToken).safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
        }
        user.rewardDebt = (user.amount * pool.accMGPPerShare) / 1e12;

        if (_amount > 0)
            if (!_isVlmgp) emit Deposit(_account, _stakingToken, _amount);
            else emit DepositNotAvailable(_account, _stakingToken, _amount);
    }

    /// @notice internal function to deal with withdraw staking token
    function _withdraw(
        address _stakingToken,
        address _account,
        uint256 _amount,
        bool _isVlMgp
    ) internal {
        _harvestAndUnstake(_stakingToken, _account, _amount, _isVlMgp);

        if (!_isVlMgp)
            IERC20(tokenToPoolInfo[_stakingToken].stakingToken).safeTransfer(
                address(msg.sender),
                _amount
            );
        emit Withdraw(_account, _stakingToken, _amount);
    }

    /// @notice Update reward variables of the given pool to be up-to-date.
    /// @param _stakingToken Staking token of the pool
    function updatePool(address _stakingToken) public  {
        PoolInfo storage pool = tokenToPoolInfo[_stakingToken];
        if (
            block.timestamp <= pool.lastRewardTimestamp || totalAllocPoint == 0
        ) {
            return;
        }
        uint256 lpSupply = _calLpSupply(_stakingToken);
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp - pool.lastRewardTimestamp;
        uint256 mgpReward = (multiplier * mgpPerSec * pool.allocPoint) /
            totalAllocPoint;

        pool.accMGPPerShare =
            pool.accMGPPerShare +
            ((mgpReward * 1e12) / lpSupply);
        pool.lastRewardTimestamp = block.timestamp;

        emit UpdatePool(
            _stakingToken,
            pool.lastRewardTimestamp,
            lpSupply,
            pool.accMGPPerShare
        );
    }

    /// @notice Update reward variables for all pools. Be mindful of gas costs!
    function massUpdatePools() public  {
        for (uint256 pid = 0; pid < registeredToken.length; ++pid) {
            updatePool(registeredToken[pid]);
        }
    }

    function _calLpSupply(
        address _stakingToken
    ) internal view returns (uint256) {
        if (_stakingToken == address(vlmgp)) {
            return IERC20(address(vlmgp)).totalSupply();
        }
        if (_stakingToken == address(mWomSV)) {
            return IERC20(address(mWomSV)).totalSupply();
        }
        return IERC20(_stakingToken).balanceOf(address(this));
    }

     function _harvestAndUnstake(
        address _stakingToken,
        address _account,
        uint256 _amount,
        bool _isVlMgp
    ) internal {
        updatePool(_stakingToken);

        UserInfo storage user = userInfo[_stakingToken][_account];

        if (!_isVlMgp && user.available < _amount)
            revert WithdrawAmountExceedsStaked();
        else if (user.amount < _amount && _isVlMgp)
            revert UnlockAmountExceedsLocked();

        _harvestMGP(_stakingToken, _account);
        _harvestBaseRewarder(_stakingToken, _account);

        user.amount = user.amount - _amount;

        if (!_isVlMgp) user.available = user.available - _amount;
        user.rewardDebt =
            (user.amount * tokenToPoolInfo[_stakingToken].accMGPPerShare) /
            1e12;
    }

    function _harvestMGP(address _stakingToken, address _account) internal {
        // Harvest MGP
        uint256 pending = _calNewMGP(_stakingToken, _account);
        unClaimedMgp[_stakingToken][_account] += pending;
    }

    /// @notice calculate MGP reward based on current accMGPPerShare
    function _calNewMGP(
        address _stakingToken,
        address _account
    ) internal view returns (uint256) {
        UserInfo storage user = userInfo[_stakingToken][_account];
        uint256 pending = (user.amount *
            tokenToPoolInfo[_stakingToken].accMGPPerShare) /
            1e12 -
            user.rewardDebt;
        return pending;
    }

     function _harvestBaseRewarder(
        address _stakingToken,
        address _account
    ) internal {
        IBaseRewardPool rewarder = IBaseRewardPool(
            tokenToPoolInfo[_stakingToken].rewarder
        );
        if (address(rewarder) != address(0)) rewarder.updateFor(_account);
    }






}