// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IRunbit.sol";

contract RunbitCollection is AccessControl {
    bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGE_ROLE, admin);
    }

    struct CardCollection {
        uint64 startId;
        uint64 stock;  
        uint64 sales;  
        uint64 price0; 
        uint112 price1;
        uint48 adjust1;
        uint48 adjust2;
        uint48 adjust3;
        uint64 baseSpecialty;
        uint64 baseComfort;
        uint64 baseAesthetic;
        uint32 durability;
        uint16 level;
        uint16 status;
    }

    struct EquipCollection {
        uint64 startId;
        uint64 stock;
        uint64 sales;
        uint32 level;
        uint16 equipType;
        uint8 status;
        uint8 upgradeable;
        uint32 capacity;
        uint48 quality;
        uint64 price0; 
        uint112 price1; 
    }
    
    // 1e8
    uint256 refRate;
    string cardBaseURI;
    string equipBaseURI;
    IRefStore refs;
    IERC20Burnable RB;
    IRunbitRand oracle;
    // can exchange card
    IERC20Burnable cardToken;
    // can exchange equipment
    IERC20Burnable equipToken;
    IRunbitCard NFTCard;
    IRunbitEquip NFTEquip;
    uint256 cardCollectCount;
    uint256 equipCollectCount;
    // cardCollections[collectionId] = collection
    mapping(uint256 => CardCollection) cardCollections;
    // equipCollections[collectionId] = collection
    mapping(uint256 => EquipCollection) equipCollections;
    // forgeNum[equipType][level] = num
    mapping(uint256 => mapping(uint256 => uint256)) forgeNum;
    // forgeEquips[equipType][level][index] = collectionId;
    // collection
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) forgeEquips;
    // forgeFee[equipType][level] = fee
    mapping(uint256 => mapping(uint256 => uint256)) forgeFee;

    modifier onlyReferral {
        require(refs.referrer(msg.sender) != address(0), "Not activated!");
        _;
    }

    function _mintCard(uint256 collectionId) internal {
        CardCollection storage cc = cardCollections[collectionId];
        IRunbitCard.MetaData memory meta;
        unchecked {
            uint256 rand = oracle.genNormalRand();
            if (cc.adjust1 > 0) {
                meta.specialty = uint64(cc.baseSpecialty + (rand & 0xffffffffffffffffffff) % cc.adjust1);
            } else {
                meta.specialty = uint64(cc.baseSpecialty);
            }
            if (cc.adjust2 > 0) {
                meta.comfort = uint64(cc.baseComfort + ((rand >> 80) & 0xffffffffffffffffffff) % cc.adjust2);
            } else {
                meta.comfort = uint64(cc.baseComfort);
            }
            if (cc.adjust3 > 0) {
                meta.aesthetic = uint64(cc.baseAesthetic + ((rand >> 160) & 0xffffffffffffffffffff) % cc.adjust3);
            } else {
                meta.aesthetic = uint64(cc.baseAesthetic);
            }
            
            meta.durability = cc.durability;
            meta.level = cc.level;
            uint256 tokenId = cc.startId + cc.sales;
            string memory uri = string.concat(cardBaseURI, Strings.toString(tokenId), ".png");
            NFTCard.safeMint(msg.sender, tokenId, uri, meta);
            cc.sales += 1;
            emit NFTCardMint(msg.sender, tokenId, collectionId, uri, meta);
        }
    }

    function _mintEquip(uint256 collectionId) internal {
        EquipCollection storage ec = equipCollections[collectionId];
        IRunbitEquip.MetaData memory meta;
        meta.level = ec.level;
        meta.capacity = ec.capacity;
        meta.equipType = ec.equipType;
        meta.quality = ec.quality;
        meta.upgradeable = ec.upgradeable;
        uint256 tokenId = ec.startId + ec.sales;
        string memory uri = string.concat(equipBaseURI, Strings.toString(tokenId), ".png");
        NFTEquip.safeMint(msg.sender, tokenId, uri, meta);
        ec.sales += 1;
        emit NFTEquipMint(msg.sender, tokenId, collectionId, uri, meta);
    }
    
    function buyCard(uint256 collectionId) external onlyReferral {
        require(collectionId < cardCollectCount, "This Card Collection does not exist!");
        CardCollection memory cc = cardCollections[collectionId];
        require((cc.status & 1) == 1 && cc.sales < cc.stock, "This Card Collection is Out of Stock");
        // burn
        RB.burnFrom(msg.sender, cc.price1);
        // ref rewrd
        address referrer = refs.referrer(msg.sender);
        uint256 amount = cc.price1 * refRate / 100000000;
        RB.mint(referrer, amount);
        emit RefeReward(referrer, msg.sender, amount);
        // mint
        _mintCard(collectionId);
        emit NFTCardBuy(msg.sender, collectionId, cc.price1);
    }
    
    function buyEquip(uint256 collectionId) external onlyReferral {
        require(collectionId < equipCollectCount, "This Equip Collection does not exist!");
        EquipCollection memory ec = equipCollections[collectionId];
        require((ec.status & 1) == 1 && ec.sales < ec.stock, "This Card Collection is Out of Stock");
        // burn
        RB.burnFrom(msg.sender, ec.price1);
        // ref rewrd
        address referrer = refs.referrer(msg.sender);
        uint256 amount = ec.price1 * refRate / 100000000;
        RB.mint(referrer, amount);
        emit RefeReward(referrer, msg.sender, amount);
        // mint
        _mintEquip(collectionId);
        emit NFTEquipBuy(msg.sender, collectionId, ec.price1);
    }
    
    function redeemCard(uint256 collectionId) external onlyReferral {
        require(collectionId < cardCollectCount, "This Card Collection does not exist!");
        CardCollection memory cc = cardCollections[collectionId];
        require((cc.status & 2) == 2 && cc.sales < cc.stock, "This Card Collection is Out of Stock");
        // burn
        cardToken.burnFrom(msg.sender, cc.price0);
        // mint
        _mintCard(collectionId);
        emit NFTCardRedeem(msg.sender, collectionId, cc.price0);
    }

    function redeemEquip(uint256 collectionId) external onlyReferral {
        require(collectionId < equipCollectCount, "This Card Collection does not exist!");
        EquipCollection memory ec = equipCollections[collectionId];
        require((ec.status & 2) == 2 && ec.sales < ec.stock, "This Card Collection is Out of Stock");
        // burn
        equipToken.burnFrom(msg.sender, ec.price0);
        // mint
        _mintEquip(collectionId);
        emit NFTEquipRedeem(msg.sender, collectionId, ec.price0);
    }

    function forgeEquip(uint256 equipId1, uint256 equipId2) external onlyReferral {
        require(NFTEquip.ownerOf(equipId1) == msg.sender, "not owner!");
        require(NFTEquip.ownerOf(equipId2) == msg.sender, "not owner!");
        
        IRunbitEquip.MetaData memory equip1 = NFTEquip.tokenMetaData(equipId1);
        IRunbitEquip.MetaData memory equip2 = NFTEquip.tokenMetaData(equipId2);
        
        require(equip1.level == equip2.level, "level is unequally!");
        require(equip1.equipType == equip2.equipType, "type is unequally!");
        require(equip1.upgradeable > 0 && equip2.upgradeable > 0, "not upgradeable!");

        uint256 num = forgeNum[equip1.equipType][equip1.level];
        require(num > 0, "can not upgrade!");
        uint256 rand = oracle.genNormalRand();
        uint256 idx = rand % num;
        uint256 cid = forgeEquips[equip1.equipType][equip1.level][idx];
        uint256 lasti = num;
        for(uint i = idx; i < num; ++i) {
            EquipCollection memory ec = equipCollections[cid];
            if(ec.sales < ec.stock && (ec.status & 4) == 4 ) {
                break;
            }
            cid = forgeEquips[equip1.equipType][equip1.level][lasti-1];
            forgeEquips[equip1.equipType][equip1.level][idx] = cid;
            lasti -= 1;
        }
        if(lasti == idx) {
            cid = forgeEquips[equip1.equipType][equip1.level][0];
            for(uint i = 0; i < idx; ++i) {
                EquipCollection memory ec = equipCollections[cid];
                if(ec.sales < ec.stock && (ec.status & 4) == 4 ) {
                    break;
                }
                cid = forgeEquips[equip1.equipType][equip1.level][lasti-1];
                forgeEquips[equip1.equipType][equip1.level][0] = cid;
                lasti -= 1;
            }
        }
        require(lasti > 0, "not avalibale!");
        if (lasti != num) {
            forgeNum[equip1.equipType][equip1.level] = lasti;
        }

        uint256 fee = forgeFee[equip1.equipType][equip1.level];
        // burn
        RB.burnFrom(msg.sender, fee);
        NFTEquip.burn(equipId1);
        NFTEquip.burn(equipId2);
        // mint
        _mintEquip(cid);
        emit NFTEquipForge(msg.sender, cid, equipId1, equipId2, fee);
    }

    function addCardCollection(CardCollection memory colection) external onlyRole(MANAGE_ROLE) {
        cardCollections[cardCollectCount] = colection;
        emit CardCollectionAdd(cardCollectCount, colection);
        cardCollectCount += 1;
    }

    function addEquipCollection(EquipCollection memory ec) external onlyRole(MANAGE_ROLE) {
        equipCollections[equipCollectCount] = ec;
        if ((ec.status & 4) == 4) {
            uint256 num = forgeNum[ec.equipType][ec.level - 1];
            forgeEquips[ec.equipType][ec.level - 1][num] = equipCollectCount;
            forgeNum[ec.equipType][ec.level - 1] += 1;
        }
        emit EquipCollectionAdd(equipCollectCount, ec);
        equipCollectCount += 1;
    }

    function setForgeFee(uint256 equipType, uint256 level, uint256 fee) external onlyRole(MANAGE_ROLE) {
        forgeFee[equipType][level] = fee;
    }

    function editCardCollection(uint256 collectionId, uint256 price0, uint256 price1, uint256 status) external onlyRole(MANAGE_ROLE) {
        cardCollections[collectionId].price0 = uint64(price0);
        cardCollections[collectionId].price1 = uint112(price1);
        cardCollections[collectionId].status = uint16(status);
    }

    function editEquipCollection(uint256 collectionId, uint256 price0, uint256 price1, uint256 status) external onlyRole(MANAGE_ROLE) {
        equipCollections[collectionId].price0 = uint64(price0);
        equipCollections[collectionId].price1 = uint112(price1);
        equipCollections[collectionId].status = uint8(status);
    }

    function setCardBaseURI(string memory baseURI) external onlyRole(MANAGE_ROLE) {
        cardBaseURI = baseURI;
    }

    function setEquipBaseURI(string memory baseURI) external onlyRole(MANAGE_ROLE) {
        equipBaseURI = baseURI;
    }

    function setRefRate(uint256 _rate) external onlyRole(MANAGE_ROLE) {
        refRate = _rate;
    }

    function setFactory(address _refs, address _rand) external onlyRole(DEFAULT_ADMIN_ROLE) {
        refs = IRefStore(_refs);
        oracle = IRunbitRand(_rand);
    }

    function setToken(address _rb, address _card, address _equip) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RB = IERC20Burnable(_rb);
        cardToken = IERC20Burnable(_card);
        equipToken = IERC20Burnable(_equip);
    }

    function setNFTs(address _card, address _equip) external onlyRole(DEFAULT_ADMIN_ROLE) {
        NFTCard = IRunbitCard(_card);
        NFTEquip = IRunbitEquip(_equip);
    }

    function getCardCollection(uint256 collectionId) external view returns (CardCollection memory cc) {
        cc = cardCollections[collectionId];
    }

    function getEquipCollection(uint256 collectionId) external view returns (EquipCollection memory ec) {
        ec = equipCollections[collectionId];
    }

    function getForgeFee(uint256 equipType, uint256 level) external view returns (uint256) {
        return forgeFee[equipType][level];
    }
    
    function getCardCollectCount() external view returns (uint256) {
        return cardCollectCount;
    }
    
    function getEquipCollectCount() external view returns (uint256) {
        return equipCollectCount;
    }

    function getCardBaseURI() external view returns (string memory) {
        return cardBaseURI;
    }

    function getEquipBaseURI() external view returns (string memory) {
        return equipBaseURI;
    }

    function getForgeNum(uint256 equipType, uint256 level) external view returns (uint256) {
        return forgeNum[equipType][level];
    }

    function getRefRate() external view returns (uint256) {
        return refRate;
    }

    event NFTCardMint(address indexed to, uint256 indexed tokenId, uint256 collectionId, string uri, IRunbitCard.MetaData meta);
    event NFTCardBuy(address indexed buyer, uint256 indexed collectionId, uint256 price);
    event NFTCardRedeem(address indexed buyer, uint256 indexed collectionId, uint256 price);
    event NFTEquipMint(address indexed to, uint256 indexed tokenId, uint256 collectionId, string uri, IRunbitEquip.MetaData meta);
    event NFTEquipBuy(address indexed buyer, uint256 indexed collectionId, uint256 price);
    event NFTEquipRedeem(address indexed buyer, uint256 indexed collectionId, uint256 price);
    event CardCollectionAdd(uint256 indexed collectionId, CardCollection cc);
    event EquipCollectionAdd(uint256 indexed collectionId, EquipCollection cc);
    event RefeReward(address indexed to, address from, uint256 amount);
    event NFTEquipForge(address indexed user, uint256 collectionId, uint256 equipId1, uint256 equipId2, uint256 fee);
}
