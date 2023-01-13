// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
pragma solidity ^0.8.14;

interface IRefStore {
    /// referrer
    function referrer(address from) external view returns (address);
    /// add referrer
    function addReferrer(address from, address to) external;
    /// referrer added
    event ReferrerAdded(address indexed to, address from);
}

interface IERC20Burnable is IERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function mint(address to, uint256 amount) external;
}

interface IDataFeed {
    function latestAnswer()  external view returns (int256);
    function latestTimestamp() external view returns (uint256);
}

interface IRunbitRand {
    function getRand(uint256 round) external view returns (uint256);
    function genNormalRand() external view returns (uint256);
}

interface IRunbitCard is IERC721 {
    struct MetaData {
        uint64 specialty;
        uint64 comfort;
        uint64 aesthetic;
        uint32 durability;
        uint32 level;
    }

    function safeMint(address to, uint256 tokenId, string memory uri, MetaData memory metaData) external;
    function tokenMetaData(uint256 tokenId) external view returns (MetaData memory);
    function burn(uint256 tokenId) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view  returns (uint256);
}

interface IRunbitEquip is IERC721 {
    struct MetaData {
        uint32 equipType;
        uint32 upgradeable;
        uint64 level;
        uint64 capacity;
        uint64 quality;
    }

    function safeMint(address to, uint256 tokenId, string memory uri, MetaData memory metaData) external;
    function tokenMetaData(uint256 tokenId) external view returns (MetaData memory);
    function burn(uint256 tokenId) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view  returns (uint256);
}

interface IStepCheck {
    function stepCheck(uint256 checkSum, address user) external view returns (uint256);
}