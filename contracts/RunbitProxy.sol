// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./IRunbit.sol";
import "./Runbit.sol";

contract RunbitProxy {
    Runbit runbit;
    IRunbitCard NFTCard;
    IRunbitEquip NFTEquip;
    IERC20Burnable RB;

    constructor(address _runbit, address _card, address _equip, address _rb) {
        runbit = Runbit(_runbit);
        NFTCard = IRunbitCard(_card);
        NFTEquip = IRunbitEquip(_equip);
        RB = IERC20Burnable(_rb);
    }
    
    struct UserInfo {
        uint256[3] equipIds; // 已装备的装备ID，0表示没有
        IRunbitEquip.MetaData[3] equipMetas; // 装备的信息，0表示没有
        string[3] equipURIs; // 装备图片的URI，0表示没有
        Runbit.EquipInfo[3] equipInfos; // 装备信息
        uint256[9] cardIds; // 三个装备三个位置的卡片ID [0,1,2][3,4,5][6,7,8]，0表示没有卡片
        uint256[9] cardConsume; // 卡片消耗的点数
        IRunbitCard.MetaData[9] cardMetas; // 卡片的详细信息
        string[9] cardURIs; // 卡片的URI地址
        Runbit.StepCount[9] cardCounts; // 属性卡的步数记录，如果不为0，则不允许卸下
        uint256 totalSpecialty; // 功能性
        uint256 totalAesthetic; // 美观性
        uint256 totalComfort; // 舒适性
        uint256 currentSteps; // 当前已同步步数
        uint256 currentRewads; // 今日预计收益
        uint256 trackId0; // 当前的跑道ID
        uint256 trackId1; // 预计生效的跑道ID
        uint256 today; // 日期ID
        uint256 cardBalance; // 卡片总量
        uint256 equipBalance; // 装备总量
        uint256 rbBalance; // RB的数量
    }

    struct CardAggInfo {
        string uri;
        uint256 id; // tokenID
        IRunbitCard.MetaData meta;
        Runbit.CardInfo info;
        Runbit.StepCount count; // 步数记录
        uint256 consume; //消耗的天数
    }

    struct EquipAggInfo {
        string uri;
        uint256 id; // tokenID
        IRunbitEquip.MetaData meta;
        Runbit.EquipInfo info;
        uint256[3] cards; // 卡槽0,1,2绑定的卡片
        string[3] cardURIs; // 卡片的uri
    }

    struct UserRewards {
        uint256[] rewards; // 收益
        Runbit.UserState[] states; // 用户状态
    }

    struct UserLotterys {
        uint256[] RT; // 抽中的RT数
        uint256[] CT; // 抽中的CT数
        uint256[] ET; // 抽中的ET数
        Runbit.UserState[] states; // 用户状态
    }
    
    function getUserInfo(address user) external view returns (UserInfo memory info) {
        info.today = (block.timestamp + 28800) / 86400;
        for(uint i = 0; i < 3; ++i) {
            info.equipIds[i] = runbit.getBindEquip(user, i);
            if (info.equipIds[i] == 0) {
                continue;
            }
            if(NFTEquip.ownerOf(info.equipIds[i]) != user) {
                info.equipIds[i] = 0;
            } else {
                info.equipMetas[i] = NFTEquip.tokenMetaData(info.equipIds[i]);
                info.equipURIs[i] = NFTEquip.tokenURI(info.equipIds[i]);
                info.equipInfos[i] = runbit.getEquipInfo(info.equipIds[i]);

                for(uint j = i*3; j < i*3+3; ++j) {
                    info.cardIds[j] = runbit.getBindCard(info.equipIds[i], j - i*3);
                    if(info.cardIds[j] == 0) {
                        continue;
                    }
                    if(NFTCard.ownerOf(info.cardIds[j]) != user) {
                        info.cardIds[j] = 0;
                    } else {
                        info.cardConsume[j] = runbit.getCardConsume(info.cardIds[j]);
                        info.cardMetas[j] = NFTCard.tokenMetaData(info.cardIds[j]);
                        info.cardURIs[j] = NFTCard.tokenURI(info.cardIds[j]);
                        info.cardCounts[j] = runbit.getCardStepCount(info.cardIds[j], info.today);
                        // 前端需判断耐久是否用完，用完则不展示
                        if(info.cardConsume[j] < info.cardMetas[j].durability) {
                            info.totalSpecialty += info.cardMetas[j].specialty;
                            info.totalComfort += info.cardMetas[j].comfort;
                            info.totalAesthetic += info.cardMetas[j].aesthetic;
                        }
                    }
                }
            }
        }

        info.currentRewads = runbit.getUnharvestReward(user, info.today);
        info.currentSteps = runbit.getUserState(user, info.today).lastSteps;
        (info.trackId0, info.trackId1) = runbit.getTrackId(user);
        info.cardBalance = NFTCard.balanceOf(user);
        info.equipBalance = NFTEquip.balanceOf(user);
        info.rbBalance = RB.balanceOf(user);
    }

    function getUserRewards(address user, uint256 from, uint256 to) external view returns (UserRewards memory rewards) {
        uint i = 0;
        uint256 len = to - from;
        rewards.rewards = new uint256[](len);
        rewards.states = new Runbit.UserState[](len);
        for(uint256 d = from; d < to; ++d) {
            uint256 reward = runbit.getUnharvestReward(user, d);
            if (reward > 0) {
                rewards.rewards[i] = reward;
                rewards.states[i] = runbit.getUserState(user, d);
            }
            ++i;
        }
    }

    function getUserLotterys(address user, uint256 from, uint256 to) external view returns (UserLotterys memory lotterys) {
        uint i = 0;
        uint256 len = to - from;
        lotterys.RT =  new uint256[](len);
        lotterys.CT =  new uint256[](len);
        lotterys.ET =  new uint256[](len);
        lotterys.states =  new Runbit.UserState[](len);
        for(uint256 d = from; d < to; ++d) {
            (uint256 rt, uint256 ct, uint256 et) = runbit.isLucky(user, d);
            if(rt > 0 || ct > 0 || et > 0) {
                lotterys.RT[i] = rt;
                lotterys.CT[i] = ct;
                lotterys.ET[i] = et;
                lotterys.states[i] = runbit.getUserState(user, d);
            }
            ++i;
        }
    }

    function getAllCards(address user) external view returns (CardAggInfo[] memory infos) {
        uint256 today = (block.timestamp + 28800) / 86400;
        uint256 balance = NFTCard.balanceOf(user);
        infos = new CardAggInfo[](balance);
        for(uint i = 0; i < balance; ++i) {
            infos[i].id = NFTCard.tokenOfOwnerByIndex(user, i);
            infos[i].meta = NFTCard.tokenMetaData(infos[i].id);
            infos[i].uri = NFTCard.tokenURI(infos[i].id);
            infos[i].consume = runbit.getCardConsume(infos[i].id);
            infos[i].count = runbit.getCardStepCount(infos[i].id, today);
            // 只有安装在自己的装备上才算
            Runbit.CardInfo memory info = runbit.getCardInfo(infos[i].id);
            if(info.equipId != 0) {
                address owner = NFTEquip.ownerOf(info.equipId);
                if (owner == user) {
                    infos[i].info = info;
                }
            }
        }
    }

    function getAllEquips(address user) external view returns (EquipAggInfo[] memory infos) {
        uint256 balance = NFTEquip.balanceOf(user);
        infos = new EquipAggInfo[](balance);
        for(uint i = 0; i < balance; ++i) {
            infos[i].id = NFTEquip.tokenOfOwnerByIndex(user, i);
            infos[i].meta = NFTEquip.tokenMetaData(infos[i].id);
            infos[i].uri = NFTEquip.tokenURI(infos[i].id);
            infos[i].info = runbit.getEquipInfo(infos[i].id);
            for(uint j = 0; j < 3; ++j) {
                uint256 cardId = runbit.getBindCard(infos[i].id, j);
                if(cardId != 0) {
                    address owner = NFTCard.ownerOf(cardId);
                    // 只有自己的属性卡才算
                    if(user == owner) {
                        infos[i].cards[j] = cardId;
                        infos[i].cardURIs[j] = NFTCard.tokenURI(cardId);
                    }
                }
            }
        }
    }
}
