// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IRunbit.sol";

contract Runbit is AccessControl {
    bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGE_ROLE, admin);
    }
    // 精度为1e18
    struct RewardRate {
        uint64 trackDecay;
        uint64 stepDecay;
        uint64 jamDecay;
        uint64 comfortBuff;
        uint64 trackCapacity;
        uint64 trackLimit;
        uint128 specialty;
        uint112 aesthetic;
        uint112 comfort;
        uint32 minSteps;
    }

    struct StepCount {
        uint64 count; 
        uint64 equipType; 
        uint64 trackId; 
    }

    struct EquipInfo {
        address owner; 
        uint64 emptyId; 
        uint32 latestDay; 
    }

    struct CardInfo {
        uint192 equipId; 
        uint64 idx; 
    }

    struct UserState {
        uint8 status; 
        uint8 lottery; 
        uint16 trackId; 
        uint32 cardCount; 
        uint64 lastSteps; 
        uint128 RBReward; 
    }

    struct DailyInfo {
        uint64 track0; 
        uint64 track1;
        uint64 track2;
        uint64 userCount;
        uint64 totalSpecialty;
        uint64 totalComfort;
        uint64 totalAesthetic;
    }
    
    struct TrackInfo {
        uint64 latest;
        uint64 prev;
        uint64 updateDay;
    }

    struct LotteryInfo {
        uint128 RBRate;
        uint64 ETRate;
        uint64 CTRate;
        uint64 RBNum;
        uint64 ETNum;
        uint64 CTNum;
    }

    uint256 paused = 1;

    uint256 public epoch = 86400;

    address public committee;

    address public techFound;

    address public bonusFound;
    // 1e8
    uint256 public commitRate;
    // 1e8
    uint256 public techRate;
    // 1e8
    uint256 public bonusRate;
    IRefStore refs;
    IERC20Burnable RB;
    IRunbitRand randFactory;
    // can exchange card
    IERC20Burnable cardToken;
    // can exchange equipment
    IERC20Burnable equipToken;
    IRunbitCard NFTCard;
    IRunbitEquip NFTEquip;
    // step check contract
    IStepCheck stepCheck;
    RewardRate rewardRate;
    LotteryInfo baseLottery;
    mapping(address => uint256) RBReward;
    // userEquips[user][equipType] = equipTokenId
    mapping(address => mapping(uint256 => uint256)) userEquips;
    // equipCards[equipTokenId][index] = cardTokenId
    mapping(uint256 => mapping(uint256 => uint256)) equipCards;
    // cardConsume[cardTokenId] = days
    mapping(uint256 => uint256) cardConsume;
    // cardStepCount[cardTokenId][day] = count
    mapping(uint256 => mapping(uint256 => StepCount)) cardStepCount;
    // userCards[user][day][index] = cardId
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) userCards;
    // equipInfo[equipId] = info
    mapping(uint256 => EquipInfo) equipInfo;
    // cardInfo[cardId] = info
    mapping(uint256 => CardInfo) cardInfo;
    // userState[user][day] = state
    mapping(address => mapping(uint256 => UserState)) userState;
    // dailyInfo[day] = info
    mapping(uint256 => DailyInfo) dailyInfo;
    // userTrack[user] = TrackInfo
    mapping(address => TrackInfo) userTrack;
    // lotteryInfo[day] = LotteryInfo
    mapping(uint256 => LotteryInfo) lotterInfo;
    // lotteryRand[day] = rand
    mapping(uint256 => uint256) lotteryRand;
    // dailyBonus[day] = bonus
    mapping(uint256 => uint256) dailyBonus;
    // dailyCommit[day] = bonus
    mapping(uint256 => uint256) dailyCommit;
    // dailyTech[day] = bonus
    mapping(uint256 => uint256) dailyTech;


    modifier onlyReferral {
        require(paused == 0 && refs.referrer(msg.sender) != address(0), "Not available!");
        _;
    }
    
    function setRand() external onlyRole(MANAGE_ROLE) {
        uint256 day = _day() - 1;
        uint256 rand = randFactory.getRand(day);
        require(rand != 0, "not start!");
        lotterInfo[day] = baseLottery;
        lotteryRand[day] = rand;
        emit RandSet(day, rand);
    }
    
    function lottery(uint256 day) external {
        require(lotteryRand[day] != 0, "E01: not start!");
        UserState storage us = userState[msg.sender][day];
        require(us.lottery == 0 && us.cardCount > 0, "E02: no chance!");
        (uint256 RBAmount, uint256 CTAmount, uint256 ETAmount) = _calcLottery(msg.sender, day);

        us.lottery = 1;
        if (RBAmount > 0) {
            RB.mint(msg.sender, RBAmount);
            emit LotteryRB(msg.sender, day, RBAmount);
        }
        if (CTAmount > 0) {
            cardToken.mint(msg.sender, CTAmount);
            emit LotteryCT(msg.sender, day, CTAmount);
        }

        if (ETAmount > 0) {
            equipToken.mint(msg.sender, ETAmount);
            emit LotteryET(msg.sender, day, ETAmount);
        }
    }
    
    function bindEquip(uint256 tokenId) external {
        EquipInfo memory ei = equipInfo[tokenId];
        address equipOwner = NFTEquip.ownerOf(tokenId);
        require(equipOwner != address(0), "E03: burned!");
        if (ei.latestDay == _day()) {
            require(ei.owner == msg.sender, "E01: owner check failed!");
        } else {
            require(equipOwner == msg.sender, "E02: owner check failed!");
        }
        IRunbitEquip.MetaData memory meta = NFTEquip.tokenMetaData(tokenId);
        userEquips[msg.sender][meta.equipType] = tokenId;
        emit EquipBind(tokenId, msg.sender);
    }
    

    function unbindEquip(uint256 equipType) external {
        userEquips[msg.sender][equipType] = 0;
        emit EquipUnbind(msg.sender, equipType);
    }

    // update steps
    function updateSteps(uint256 steps) external onlyReferral {
        steps = stepCheck.stepCheck(steps, msg.sender);
        uint256 today = _day();
        uint256 trackId = _trackId();
        UserState storage us = userState[msg.sender][today];
        DailyInfo storage dinf = dailyInfo[today];
        require(steps > us.lastSteps, "E01: no need to update!");

        unchecked {
            if(us.lastSteps == 0) {
                dinf.userCount += 1;
                us.trackId = uint16(trackId);
            }
            steps -= us.lastSteps;
            us.lastSteps += uint64(steps);

            for(uint i = 0; i < 3; ++i) {
                uint256 eid = userEquips[msg.sender][i];
                if (eid != 0) {
                    EquipInfo storage info = equipInfo[eid];
                    address equipOwner = NFTEquip.ownerOf(eid);

                    if (equipOwner == address(0)) {
                        userEquips[msg.sender][i] = 0;
                        continue;
                    }

                    if (info.latestDay != today) {
                        if (equipOwner == msg.sender) {
                            info.owner = msg.sender;
                            info.latestDay = uint32(today);
                        } else {

                            userEquips[msg.sender][i] = 0;
                            continue;
                        }
                    }
                    IRunbitEquip.MetaData memory meta = NFTEquip.tokenMetaData(eid);
                    for(uint j = 0; j < meta.capacity; ++j) {
                        uint256 cid = equipCards[eid][j];
                        if (cid != 0) {
                            StepCount storage sc = cardStepCount[cid][today];
                            IRunbitCard.MetaData memory cm = NFTCard.tokenMetaData(cid);
                            // update card
                            if (sc.count == 0) {
                                if (cardConsume[cid] >= cm.durability) {
                                    continue;
                                }

                                if (NFTCard.ownerOf(cid) != msg.sender) {
                                    delete cardInfo[cid];
                                    equipCards[eid][j] = 0;

                                    continue;
                                }

                                dinf.totalAesthetic += cm.aesthetic;
                                dinf.totalSpecialty += cm.specialty;
                                dinf.totalComfort += cm.comfort;
                                if (trackId == 0) {
                                    dinf.track0 += cm.level;
                                } else if (trackId == 1) {
                                    dinf.track1 += cm.level;
                                } else {
                                    dinf.track2 += cm.level;
                                }
                                
                                cardConsume[cid] += 100 * epoch / 86400;
                                sc.equipType = uint64(i);
                                sc.trackId = uint64(trackId);
                                userCards[msg.sender][today][us.cardCount] = cid;
                                us.cardCount += 1;
                                emit CardUse(cid, msg.sender);
                            }
                            sc.count += uint64(steps);
                        }
                    }
                }
            }            
        }
    }
    

    function bindCard(uint256 equipId, uint256 cardId, uint256 index) external {
        require(equipInfo[equipId].latestDay != _day(), "Try it tomorrow!");
        require(NFTEquip.ownerOf(equipId) == msg.sender, "Not owner!");
        require(NFTCard.ownerOf(cardId) == msg.sender, "Not owner!");
        IRunbitEquip.MetaData memory equip = NFTEquip.tokenMetaData(equipId);
        IRunbitCard.MetaData memory card = NFTCard.tokenMetaData(cardId);
        require(index < equip.capacity, "invalid index!");
        require(card.level <= equip.level, "invalid level!");
        delete cardInfo[equipCards[equipId][index]];
        CardInfo storage info = cardInfo[cardId];
        if(info.equipId > 0) {
            equipCards[info.equipId][info.idx] = 0;
        }
        equipCards[equipId][index] = cardId;
        info.equipId = uint192(equipId);
        info.idx = uint64(index);
        emit CardBind(cardId, msg.sender, equipId, index);
    }
    
    function unbindCard(uint256 equipId, uint256 index) external {
        require(equipInfo[equipId].latestDay != _day(), "Try it tomorrow!");
        require(NFTEquip.ownerOf(equipId) == msg.sender, "Not owner!");
        emit CardUnbind(equipCards[equipId][index], msg.sender, equipId, index);
        delete cardInfo[equipCards[equipId][index]];
        equipCards[equipId][index] = 0;
    }
    
    function updateTrack(uint256 trackId) external {
        require(userEquips[msg.sender][trackId] != 0, "no equip!");
        TrackInfo storage ut = userTrack[msg.sender];
        uint256 today = _day();
        if (today == ut.updateDay) {
            ut.latest = uint64(trackId);
        } else {
            ut.updateDay = uint64(today); 
            ut.prev = ut.latest;
            ut.latest = uint64(trackId);
        }
        emit TrackChange(msg.sender, trackId);
    }
    
    function harvest(uint256 startDay, uint256 endDay) external {
        require(endDay <= _day(), "invalid endDay");
        unchecked {
            for (uint day = startDay; day < endDay; ++day) {
                uint256 reward = _calcReward(msg.sender, day);
                if (reward > 0) {
                    UserState storage us = userState[msg.sender][day];
                    us.RBReward = uint128(reward);
                    us.status = 1;
                    RBReward[msg.sender] += reward;
                    emit RBHarvest(msg.sender, reward, day);
                }
            }            
        }
    }

    function claimBonus(uint256 day) external onlyRole(MANAGE_ROLE) {
        require(day < _day(), "too early!");
        require(dailyBonus[day] == 0 && dailyCommit[day] == 0 && dailyTech[day] == 0, "claimed!");
        (uint256 commitAmount, uint256 techAmount, uint256 bonusAmount) = _calcBonus(day);
        dailyBonus[day] = bonusAmount;
        dailyCommit[day] = commitAmount;
        dailyTech[day] = techAmount;
        RB.mint(committee, commitAmount);
        RB.mint(techFound, techAmount);
        RB.mint(bonusFound, bonusAmount);
        emit BonusClaim(day, commitAmount, techAmount, bonusAmount);
    }

    function claim(uint256 amount, address to) external {
        require(amount <= RBReward[msg.sender], "E01: insufficient amount!");
        unchecked {
            RBReward[msg.sender] -= amount;    
        }
        RB.mint(to, amount);
        emit RBClaim(msg.sender, to, amount);
    }
    
    // commit tech bonus
    function _calcBonus(uint256 day) private view returns (uint256, uint256, uint256) {
        uint256 totalReward = 0;
        unchecked {
            totalReward += uint256(dailyInfo[day].totalAesthetic) * rewardRate.aesthetic;
            totalReward += uint256(dailyInfo[day].totalSpecialty) * rewardRate.specialty;
            totalReward += uint256(dailyInfo[day].totalComfort) * rewardRate.comfort;    
        }
        return (totalReward * commitRate / 100000000, totalReward * techRate / 100000000, totalReward * bonusRate / 100000000);
    }

    function _calcReward(address user, uint256 day) private view returns (uint256) {
        uint256 reward = 0;
        UserState memory us = userState[user][day];
        //
        if (us.status == 0) {
            unchecked {
                for(uint i = 0; i < us.cardCount; ++i) {
                    uint256 cid = userCards[user][day][i];
                    reward += _calcCardReward(cid, day);
                }    
            }
        }
        return reward;
    }

    function _calcCardReward(uint256 cid, uint256 day) private view returns (uint256 baseReward) {
        IRunbitCard.MetaData memory meta = NFTCard.tokenMetaData(cid);
        StepCount memory sc = cardStepCount[cid][day];
        uint256 trackCount;
        uint256 baseReward2;
        if (sc.trackId == 0) {
            trackCount = dailyInfo[day].track0;
        } else if (sc.trackId == 1) {
            trackCount = dailyInfo[day].track1;
        } else {
            trackCount = dailyInfo[day].track2;
        }
        unchecked {
            baseReward = uint256(rewardRate.specialty) * meta.specialty;
            baseReward += uint256(rewardRate.aesthetic) * meta.aesthetic;
            baseReward2 = uint256(rewardRate.comfort) * meta.comfort;   
        }

        if (trackCount > rewardRate.trackCapacity) {
            if (trackCount > rewardRate.trackLimit) {
                trackCount = rewardRate.trackLimit;
            }
            baseReward -= baseReward * (trackCount - rewardRate.trackCapacity) * rewardRate.jamDecay / 1000000000000000000;

            baseReward2 -= baseReward2 * (trackCount - rewardRate.trackCapacity) * (rewardRate.jamDecay - rewardRate.comfortBuff) / 1000000000000000000;
        }
        unchecked {
            baseReward += baseReward2;
        }

        if (sc.equipType != sc.trackId) {
            baseReward -= baseReward * rewardRate.trackDecay / 1000000000000000000;
        }

        if(sc.count < rewardRate.minSteps) {
            baseReward -= baseReward * (rewardRate.minSteps - sc.count) * rewardRate.stepDecay / 1000000000000000000;
        }
    }

    function _calcLottery(address user, uint256 day) private view returns (uint256 RBAmount, uint256 CTAmount, uint256 ETAmount) {
        uint256 totalAesthetic = dailyInfo[day].totalAesthetic;
        if(totalAesthetic == 0) {
            return (0, 0, 0);
        }
        uint256 aesthetic = 0;
        UserState memory us = userState[user][day];
        unchecked {
            for(uint i = 0; i < us.cardCount; ++i) {
                uint256 cid = userCards[user][day][i];
                IRunbitCard.MetaData memory meta = NFTCard.tokenMetaData(cid);
                aesthetic += meta.aesthetic;
            }
            LotteryInfo memory li = lotterInfo[day];
            //RB
            uint256 rand = uint256(keccak256(abi.encodePacked(user, lotteryRand[day])));
            uint256 chance = rand % totalAesthetic;
            if (chance < li.RBNum * aesthetic) {
                RBAmount = totalAesthetic * li.RBRate;
            }

            rand = uint256(keccak256(abi.encodePacked(user, rand)));
            chance = rand % totalAesthetic;
            if (chance < li.RBNum * aesthetic) {
                CTAmount = totalAesthetic * li.CTRate / 100000000;
            }

            rand = uint256(keccak256(abi.encodePacked(user, rand)));
            chance = rand % totalAesthetic;
            if (chance < li.RBNum * aesthetic) {
                ETAmount = totalAesthetic * li.ETRate / 100000000;
            }    
        }
    }

    function setFound(address _commit, address _tech, address _bonus) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (techFound, committee, bonusFound) = (_tech, _commit, _bonus);
    }
    // 1e8
    function setRate(uint256 _commit, uint256 _tech, uint256 _bonus) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (techRate, commitRate, bonusRate) = (_tech, _commit, _bonus);
    }
    
    function setFactorys(address _refs, address _rand, address _stepCheck) external onlyRole(DEFAULT_ADMIN_ROLE) {
        refs = IRefStore(_refs);
        randFactory = IRunbitRand(_rand);
        stepCheck = IStepCheck(_stepCheck);
    }

    function setTokens(address _rb, address _cardToken, address _equipToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RB = IERC20Burnable(_rb);
        cardToken = IERC20Burnable(_cardToken);
        equipToken = IERC20Burnable(_equipToken);
    }

    function setNFTs(address _card, address _equip) external onlyRole(DEFAULT_ADMIN_ROLE) {
        NFTCard = IRunbitCard(_card);
        NFTEquip = IRunbitEquip(_equip);
    }

    function setRewardRate(RewardRate memory rate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardRate = rate;
    }

    function setBaseLottery(LotteryInfo memory _baseLottery) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseLottery = _baseLottery;
    }

    function setEpoch(uint256 _epoch) external onlyRole(DEFAULT_ADMIN_ROLE) {
        epoch = _epoch;
    }
    
    // 1: pause，0：start
    function pause(uint256 _v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = _v;
    }

    function _day() private view returns (uint256) {
        return (block.timestamp + 28800) / epoch;
    }
    
    function _trackId() private view returns (uint256) {
        TrackInfo memory ut = userTrack[msg.sender];
        if (_day() == ut.updateDay) {
            return ut.prev;
        } else {
            return ut.latest;
        }
    }
    
    function getTrackId() external view returns (uint256, uint256) {
        return (_trackId(), userTrack[msg.sender].latest);
    }

    function getUserState(address user, uint256 day) external view returns (UserState memory us) {
        us = userState[user][day];
    }
    
    function getUnharvestReward(address user, uint256 day) external view returns (uint256) {
        UserState memory us = userState[user][day];
        if (us.status == 1) {
            return us.RBReward;
        } else {
            return _calcReward(user, day);
        }
    }
    
    function getUnclaimReward(address user) external view returns (uint256) {
        return RBReward[user];
    }
    
    function getBindEquip(address user, uint256 equipType) external view returns (uint256) {
        return userEquips[user][equipType];
    }
    
    function getBindCard(uint256 equipId, uint256 index) external view returns (uint256) {
        return equipCards[equipId][index];
    }
    
    function getCardConsume(uint256 cardId) external view returns (uint256) {
        return cardConsume[cardId];
    }
    
    function getCardStepCount(uint256 cardId, uint256 day) external view returns (StepCount memory count) {
        count = cardStepCount[cardId][day];
    }
    
    function getEquipInfo(uint256 equipId) external view returns (EquipInfo memory info) {
        info = equipInfo[equipId];
    }
    
    function getCardInfo(uint256 cardId) external view returns (CardInfo memory info) {
        info = cardInfo[cardId];
    }
    
    function getDailyInfo(uint256 day) external view returns (DailyInfo memory info) {
        info = dailyInfo[day];
    }
    
    function getLotteryRand(uint256 day) external view returns (uint256) {
        return lotteryRand[day];
    }
    
    function getDailyBonus(uint256 day) external view returns (uint256, uint256, uint256) {
        return (dailyCommit[day], dailyTech[day], dailyBonus[day]);
    }

    function isLucky(address user, uint256 day) external view returns (uint256, uint256, uint256) {
        if(lotteryRand[day] == 0) {
            return (0, 0, 0);
        }
        return _calcLottery(user, day);
    }
    
    function getUserCards(address user, uint256 day, uint256 index) external view returns (uint256) {
        return userCards[user][day][index];
    }

    function getCardsReward(uint256 cid, uint256 day) external view returns (uint256) {
        return  _calcCardReward(cid, day);
    }

    function getRewardRate() external view returns (RewardRate memory) {
        return rewardRate;
    }
    
    event EquipBind(uint256 indexed tokenId, address indexed user);
    event EquipUnbind(address indexed user, uint256 equipType);
    event CardUse(uint256 indexed tokenId, address indexed user);
    event CardBind(uint256 indexed cardId, address indexed user, uint256 equipId, uint256 index);
    event CardUnbind(uint256 indexed cardId, address indexed user, uint256 equipId, uint256 index);
    event TrackChange(address indexed user, uint256 trackId);
    event LotteryRB(address indexed user, uint256 day, uint256 amount);
    event LotteryCT(address indexed user, uint256 day, uint256 amount);
    event LotteryET(address indexed user, uint256 day, uint256 amount);
    event RBClaim(address indexed owner, address to, uint256 amount);
    event RBHarvest(address indexed user, uint256 amount, uint256 day);
    event RandSet(uint256 indexed day, uint256 rand);
    event BonusClaim(uint256 indexed day, uint256 commitAmount, uint256 techAmount, uint256 bonusAmount);
}