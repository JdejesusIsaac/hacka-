// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuard } from "./ReentrancyGuard.sol";

import  "./ILaunchpadVesting.sol";


contract Launchpad is
    OwnableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 priorityQuota; // user's priority access quota for project token without any mulitplier
        uint256 lowFDVPurchased; // project token priority purchae
        uint256 highFDVPurchased; // project token public purchase
        bool tokenClaimed; // claimed project token
    }

    struct PhaseInfo {
        uint256 endTime;
        uint256 saleCap; // project token sale cap
        uint256 allocatedAmount; // project token allocated
        uint256 tokenPerSaleToken; // project token per sale token in DENOMINATOR
        uint256 priorityMultiplier; // > 0 for priority sale, = 0 for public sale in DENOMINATOR
        bool isLofFDV;
    }

    uint256 public constant DENOMINATOR = 10000;
    uint256 public LOW_FDV_VESTING_PART; // Some % part of claimed amount during priority phase will be vested
    uint256 public HIGH_FDV_VESTING_PART; // Some % part of claimed amount during public phase will be vested

    IERC20 public projectToken; // Project token contract
    IERC20 public saleToken; // token used to purchase IDO
    ILaunchpadVesting public vestingContract;

    uint256 public startTime; // sale start time
    uint256 public max_launch_tokens_to_distribute; // max PROJECT_TOKEN amount to distribute during the sale

    mapping(address => UserInfo) public userInfo; // users claim & priority cap data
    mapping(bytes32 => uint256) public userPurchased; // Mapping user + phase => purchased. The index is hashed based on the user address and phase number
    PhaseInfo[] public phaseInfos;

    uint256 public maxRaiseAmount; // max amount of Sale Token to raise
    uint256 public totalRaised; // total amount of Sale Token raised
    uint256 public totalAllocated; // total amount of Project Tokens allocated

    address public treasury; // Address of treasury multisig, it will receive raised amount

    bool public canClaimTokens;
    bool public unsoldTokensWithdrew;

    uint256 public projectTokenDecimal;
    uint256 public saleTokenDecimal;

    /* ============ Constructor ============ */
    constructor() {
        _disableInitializers();
    }

    /****************** EVENTS ******************/

    event Claim(address indexed user, uint256 priorityPhaseClaimable, uint256 publicPhaseClaimable);
    event PriorityAccessUpdated();
    event EmergencyWithdraw(address token, uint256 amount);
    event ClaimingPhaseStarted();
    event UnsoldTokensWithdrawn(address indexed withdrawer, uint256 amount);

    /****************** ERRORS ******************/

    error InvalidPhase();
    error NoAvailablePhase();
    error InvalidAmount();
    error InvalidLength();
    error ZeroAddress();
    error SaleNotStarted();
    error SaleNotCompleted();
    error SaleCompleted();
    error NotEnoughToken();
    error RaisedMaxAmount();
    error AlreadyWithdrawn();
    error ClaimingPhaseNotStartedYet();
    error ClaimingPhaseAlreadyStarted();
    error ExceedsUserPriorityCap();

    /* ============ Initializer ============ */

   

    /****************** MODIFIERS ******************/

    /// @dev Check whether the sale is currently active
    /// Will be marked as inactive if PROJECT_TOKEN has not been deposited into the contract
    modifier isSaleActive() {
        if (!hasStarted()) revert SaleNotStarted();
        if (hasEnded()) revert SaleCompleted();
        _;
    }

    /// @dev Check whether users can claim their purchased PROJECT_TOKEN or not
    modifier isClaimable() {
        if (!hasEnded()) revert SaleNotCompleted();
        if (!canClaimTokens) revert ClaimingPhaseNotStartedYet();
        _;
    }

    /****************** PUBLIC VIEWS ******************/

    /// @dev Returns whether the sale has already started
    function hasStarted() public view returns (bool) {
        return _currentBlockTimestamp() >= startTime;
    }

    /// @dev Returns whether the sale has already ended
    function hasEnded() public view returns (bool) {
        uint256 length = phaseInfos.length;
        if (length == 0) return true;

        return phaseInfos[length - 1].endTime <= _currentBlockTimestamp();
    }

    function getUserPurchased(address _user, uint256 _phaseNumber) external view returns (uint256) {
        bytes32 identifier = _getUserPurchasedIdentifier(_user, _phaseNumber);
        return userPurchased[identifier];
    }

    /// @dev Returns current running Phase number.
    function getCurrentPhaseInfo()
        public
        view
        returns (uint256 phaseNumber, PhaseInfo memory phaseInfo)
    {
        uint256 currentBlockTimestamp = _currentBlockTimestamp();
        uint256 length = phaseInfos.length;

        if (currentBlockTimestamp < startTime) {
            return (0, phaseInfo);
        } // not started

        for (uint256 i = 0; i < length; i++) {
            phaseInfo = phaseInfos[i];
            if (currentBlockTimestamp < phaseInfo.endTime) return (i + 1, phaseInfo);
        }

        revert NoAvailablePhase();
    }

    /// @dev Get user token amount to claim
    function getExpectedClaimAmount(
        address account
    ) public view returns (uint256 lowFDVPurchased, uint256 highFDVPurchased) {
        if (totalAllocated == 0) return (0, 0);

        UserInfo memory user = userInfo[account];
        if (user.tokenClaimed) return (0, 0);

        lowFDVPurchased = user.lowFDVPurchased;
        highFDVPurchased = user.highFDVPurchased;
    }

    /****************** EXTERNAL FUNCTIONS  ******************/

    /// @dev Purchase an PROJECT_TOKEN allocation for the sale for a value of "amount" saleToken or Eth
    function buy(uint256 amount) external  isSaleActive nonReentrant {
        (uint256 phaseNumber, PhaseInfo memory phaseInfo) = getCurrentPhaseInfo();

        _checkValidCapAndUpdate(amount, phaseNumber);
        _checkValidAndBuy(msg.sender, amount, phaseNumber, phaseInfo);

        saleToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @dev Claim purchased PROJECT_TOKEN during the sale
    function claim() external  isClaimable nonReentrant {
        (uint256 lowFDVPurchased, uint256 highFDVPurchased) = getExpectedClaimAmount(msg.sender);

        if (lowFDVPurchased == 0 && highFDVPurchased == 0) revert InvalidAmount();

        UserInfo storage user = userInfo[msg.sender];
        user.tokenClaimed = true;

        if (user.lowFDVPurchased != 0) {
            _processClaims(true, user.lowFDVPurchased, msg.sender);
        }

        if (user.highFDVPurchased != 0) {
            _processClaims(false, user.highFDVPurchased, msg.sender);
        }

        emit Claim(msg.sender, lowFDVPurchased, highFDVPurchased);
    }

    /********************** ADMIN FUNCTIONS  **********************/

    /// @dev Assign priority access status and cap for users
    function setUsersPriorityAccess(
        address[] calldata users,
        uint256[] calldata userQuota
    ) public onlyOwner {
        if (users.length != userQuota.length) revert InvalidLength();
        for (uint256 i = 0; i < users.length; ++i) {
            UserInfo storage user = userInfo[users[i]];
            user.priorityQuota = userQuota[i];
        }

        emit PriorityAccessUpdated();
    }

    /// @dev Withdraw unsold PROJECT_TOKEN if max_launch_tokens_to_distribute has not been reached
    /// Must only be called by the owner
    function withdrawUnsoldTokens() external onlyOwner {
        if (!hasEnded()) revert SaleNotCompleted();
        if (unsoldTokensWithdrew) revert AlreadyWithdrawn();

        unsoldTokensWithdrew = true;
        uint256 amountOfUnsoldTokens = (max_launch_tokens_to_distribute - totalAllocated);

        projectToken.safeTransfer(owner(), amountOfUnsoldTokens);
        emit UnsoldTokensWithdrawn(msg.sender, amountOfUnsoldTokens);
    }

    /// @dev Start Tokens Claiming Phase
    function startClaimingPhase() external onlyOwner {
        if (!hasEnded()) revert SaleNotCompleted();
        if (canClaimTokens) revert ClaimingPhaseAlreadyStarted();

        canClaimTokens = true;

        vestingContract.setVestingStartTime(_currentBlockTimestamp());
        emit ClaimingPhaseStarted();
    }

    function addPhase(
        uint256 endTime,
        uint256 saleCap,
        uint256 tokenPerSaleToken,
        uint256 priorityMultiplier,
        bool isLofFDV
    ) external onlyOwner {
        PhaseInfo memory newPhase = PhaseInfo({
            endTime: endTime,
            saleCap: saleCap,
            allocatedAmount: 0,
            tokenPerSaleToken: tokenPerSaleToken,
            priorityMultiplier: priorityMultiplier,
            isLofFDV: isLofFDV
        });

        phaseInfos.push(newPhase);
    }

    function setPhase(
        uint256 index,
        uint256 endTime,
        uint256 saleCap,
        uint256 tokenPerSaleToken,
        uint256 priorityMultiplier,
        bool isLofFDV
    ) external onlyOwner {
        if (index > phaseInfos.length) revert InvalidPhase();

        PhaseInfo storage phase = phaseInfos[index];

        phase.endTime = endTime;
        phase.saleCap = saleCap;
        phase.tokenPerSaleToken = tokenPerSaleToken;
        phase.priorityMultiplier = priorityMultiplier;
        phase.isLofFDV = isLofFDV;
    }

    function configLaunchpad(
        address _projectToken,
        address _saleToken,
        address _vestingContract,
        address _treasury,
        uint256 _startTime,
        uint256 _maxToDistribute,
        uint256 _maxToRaise,
        uint256 _lowFDVVestingPart,
        uint256 _highFDVVestingPart,
        uint256 _projectTokenDecimal,
        uint256 _saleokenDecimal
    ) public onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_maxToDistribute == 0) revert InvalidAmount();
        if (_maxToRaise == 0) revert InvalidAmount();

        projectToken = IERC20(_projectToken);
        saleToken = IERC20(_saleToken);
        vestingContract = ILaunchpadVesting(_vestingContract);
        startTime = _startTime;
        treasury = _treasury;
        max_launch_tokens_to_distribute = _maxToDistribute;
        maxRaiseAmount = _maxToRaise;
        LOW_FDV_VESTING_PART = _lowFDVVestingPart;
        HIGH_FDV_VESTING_PART = _highFDVVestingPart;

        projectTokenDecimal = _projectTokenDecimal;
        saleTokenDecimal = _saleokenDecimal;
    }

    /****************** /!\ EMERGENCY ONLY ******************/

    /// @dev Emergency Withdraw for Failsafe
    function emergencyWithdrawFunds(address token, uint256 amount) external  onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);

        emit EmergencyWithdraw(token, amount);
    }

    

    /* ============ Internal Functions ============ */

    function _getUserPurchasedIdentifier(
        address _user,
        uint256 _phaseNumber
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _phaseNumber));
    }

    function _checkValidAndBuy(
        address _buyer,
        uint256 _saleTokenAmount,
        uint256 _phaseNumber,
        PhaseInfo memory phaseInfo
    ) internal {
        UserInfo storage user = userInfo[_buyer];
        uint256 _toAllocated = _tokenAllocBySale(_saleTokenAmount, phaseInfo);
        bytes32 identifier = _getUserPurchasedIdentifier(_buyer, _phaseNumber);

        userPurchased[identifier] += _toAllocated;

        // only for priority access pass check
        if (phaseInfo.priorityMultiplier > 0) {
            uint256 _userCap = _tokenAllocBySale(
                ((user.priorityQuota * phaseInfo.priorityMultiplier) / DENOMINATOR),
                phaseInfo
            );

            if (userPurchased[identifier] > _userCap) revert ExceedsUserPriorityCap();
        }

        if (phaseInfo.isLofFDV) user.lowFDVPurchased += _toAllocated;
        else user.highFDVPurchased += _toAllocated;
    }

    function _checkValidCapAndUpdate(uint256 _saleTokenAmount, uint256 _phaseNumber) internal {
        PhaseInfo storage phaseInfo = phaseInfos[_phaseNumber - 1];

        totalRaised += _saleTokenAmount;

        if (totalRaised > maxRaiseAmount) revert RaisedMaxAmount();

        uint256 amountOfTokensToBeAllocated = _tokenAllocBySale(_saleTokenAmount, phaseInfo);

        totalAllocated += amountOfTokensToBeAllocated;
        phaseInfo.allocatedAmount += amountOfTokensToBeAllocated;

        if (
            totalAllocated > max_launch_tokens_to_distribute ||
            phaseInfo.allocatedAmount > phaseInfo.saleCap
        ) revert NotEnoughToken();
    }

    function _tokenAllocBySale(
        uint256 _saleTokenAmount,
        PhaseInfo memory phaseInfo
    ) internal view returns (uint256) {
        uint256 numerator = _saleTokenAmount * phaseInfo.tokenPerSaleToken * projectTokenDecimal;
        uint256 denominator = DENOMINATOR * saleTokenDecimal;

        return numerator / denominator;
    }

    /// @dev Process user's claims for low/high FDV sale
    function _processClaims(bool isLowFDV, uint256 claimAmountForPhase, address to) internal {
        uint256 vestingAmount;
        if (isLowFDV) {
            vestingAmount = (claimAmountForPhase * LOW_FDV_VESTING_PART) / DENOMINATOR;
        } else {
            vestingAmount = (claimAmountForPhase * HIGH_FDV_VESTING_PART) / DENOMINATOR;
        }

        projectToken.safeTransfer(to, claimAmountForPhase - vestingAmount);

        if (vestingAmount != 0) {
            projectToken.approve(address(vestingContract), vestingAmount);
            vestingContract.vestTokens(isLowFDV, vestingAmount, to);
        }
    }

    /// @dev Utility function to get the current block timestamp
    function _currentBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}

   