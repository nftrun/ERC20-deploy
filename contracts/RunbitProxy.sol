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
        uint256[9] cardIds; // 三个装备三个位置的卡片ID [0,1,2][3,4,5][6,7,8]，0表示没有卡片
        uint256[9] cardConsume; // 卡片消耗的点数
        IRunbitCard.MetaData[9] cardMetas; // 卡片的详细信息
        string[9] cardURIs; // 卡片的URI地址
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
        (info.trackId0, info.trackId1) = runbit.getTrackId();
        info.cardBalance = NFTCard.balanceOf(user);
        info.equipBalance = NFTEquip.balanceOf(user);
        info.rbBalance = RB.balanceOf(user);
    }
}
