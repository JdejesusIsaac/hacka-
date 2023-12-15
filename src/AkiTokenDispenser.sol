// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AkiOracle.sol";

contract AkiTokenDispenser is Ownable {
    struct BillEnvelope {
        IERC20 token;
        string activityId;
        uint256 share;
        uint256 totalShare;
        uint256 amount;
        bool redemption;
    }

    enum ActiveStatus {
        WAITINGFORAWARD,
        AWARDING
    }

    struct ActivityListEnvelope {
        address akiUser;
        uint256 share;
    }

    struct ActivityEnvelope {
        IERC20 token;
        string activityId;
        uint256 amount;
        uint256 distribute;
        uint256 totalShare;
        uint256 winner;
        uint256 recipient;
        ActiveStatus state;
    }

    mapping(address => BillEnvelope[]) public accountBook;
    mapping(string => ActivityListEnvelope[]) public activityList;
    mapping(string => ActivityEnvelope) public activity;
    string[] public activityIdList;

    event addActivity(IERC20 token, string activityId, uint256 amount);
    event receiveAward(IERC20 token, string activityId, uint256 amount);

    function hashCompareInternal(
        string memory a,
        string memory b
    ) internal returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function receiveEventRewards(string[] memory activityId) public {
        require(activityId.length > 0, "Invalid activity!");
        for (uint32 i = 0; i < activityId.length; i++) {
            bool exist = true;
            require(activity[activityId[i]].amount != 0, "Invalid activity!");
            require(
                activity[activityId[i]].state == ActiveStatus.AWARDING,
                "The event is not open for prize collection!"
            );
            for (uint32 x = 0; x < accountBook[msg.sender].length; x++) {
                BillEnvelope storage akiUserBill = accountBook[msg.sender][x];
                if (
                    hashCompareInternal(activityId[i], akiUserBill.activityId)
                ) {
                    exist = false;
                }
            }

            require(exist, "Repeat award!");

            generateBill(activityId[i]);
        }
    }

    function generateBill(string memory activityId) private {
        ActivityListEnvelope[] storage activityListInfo = activityList[
            activityId
        ];

        ActivityEnvelope storage activityInfo = activity[activityId];
        for (uint32 x = 0; x < activityListInfo.length; x++) {
            if (activityListInfo[x].akiUser == msg.sender) {
                BillEnvelope[] storage akiUserBill = accountBook[msg.sender];
                BillEnvelope memory newBill;

                newBill.token = activityInfo.token;
                newBill.activityId = activityId;
                newBill.share = activityListInfo[x].share;
                newBill.totalShare = activityInfo.totalShare;
                newBill.amount =
                    (activityInfo.amount / activityInfo.totalShare) *
                    newBill.share;
                newBill.redemption = true;

                activityInfo.distribute += newBill.amount;
                activityInfo.recipient += 1;
                akiUserBill.push(newBill);
                activityInfo.token.transfer(msg.sender, newBill.amount);
                emit receiveAward(
                    activityInfo.token,
                    activityId,
                    newBill.amount
                );
                return;
            }
        }
        require(false, "Not on the list");
    }

    function setActiveStatus(
        string memory activityId,
        uint256 totalShare
    ) public onlyOwner returns (ActiveStatus) {
        require(activity[activityId].amount != 0, "Invalid activity!");
        ActivityEnvelope storage activityInfo = activity[activityId];
        if (activityInfo.state == ActiveStatus.WAITINGFORAWARD) {
            activityInfo.state = ActiveStatus.AWARDING;
        } else {
            activityInfo.state = ActiveStatus.WAITINGFORAWARD;
        }
        activityInfo.totalShare = totalShare;

        return activityInfo.state;
    }

    function setTokenInfo(
        string memory activityId,
        address[] memory payees,
        uint64[] calldata shares
    ) public onlyOwner {
        ActivityListEnvelope[] storage activityListInfo = activityList[
            activityId
        ];
        ActivityEnvelope storage activityInfo = activity[activityId];
        activityInfo.winner += payees.length;
        for (uint32 i = 0; i < payees.length; i++) {
            ActivityListEnvelope memory akiUserInfo;
            akiUserInfo.akiUser = payees[i];
            akiUserInfo.share = shares[i];
            activityListInfo.push(akiUserInfo);
        }
    }

    function addPayment(
        IERC20 token,
        uint256 amount,
        string calldata activityId
    ) public onlyOwner {
        require(address(token) != address(0), "Cannot be zero address!");
        require(activity[activityId].amount == 0, "activity already exists!");
        require(amount != 0, "Amount cannot be zero");
        ActivityEnvelope storage activityInfo = activity[activityId];
        activityInfo.token = token;
        activityInfo.activityId = activityId;
        activityInfo.amount = amount;
        activityInfo.distribute = 0;
        activityInfo.winner = 0;
        activityInfo.recipient = 0;
        activityInfo.totalShare = 0;
        activityInfo.state = ActiveStatus.WAITINGFORAWARD;

        string[] storage activityIdList_ = activityIdList;
        activityIdList_.push(activityId);

        token.transferFrom(msg.sender, address(this), amount);
        emit addActivity(activityInfo.token, activityInfo.activityId, amount);
    }

    function bill(address id) public view returns (BillEnvelope[] memory) {
        BillEnvelope[] memory billInfo = accountBook[id];
        return billInfo;
    }

    function activityInfo() public view returns (ActivityEnvelope[] memory) {
        ActivityEnvelope[] memory activityInfoList = new ActivityEnvelope[](
            activityIdList.length
        );
        for (uint i = 0; i < activityIdList.length; i++) {
            ActivityEnvelope storage activityInfo = activity[activityIdList[i]];
            activityInfoList[i] = activityInfo;
        }
        return activityInfoList;
    }

    function returnEnvelope(IERC20 token, uint256 amount) public onlyOwner {
        token.transfer(msg.sender, amount);
        return;
    }
}