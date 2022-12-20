// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract RunbitEquip is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl, ERC721Burnable {
    struct MetaData {
        uint32 equipType;
        uint32 upgradeable;
        uint64 level;
        uint64 capacity;
        uint64 quality;
    }
    mapping(uint256 => MetaData) private _metaData;
    mapping(uint256 => uint256) private _locked;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant LOCK_ROLE = keccak256("LOCK_ROLE");
    bool _lockMinter = false;
    string public baseURI;

    constructor(address admin) ERC721("Runbit Equip", "RBE") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(LOCK_ROLE, admin);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _base) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _base;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function lock(uint256 tokenId) external onlyRole(LOCK_ROLE) {
        _locked[tokenId] = 1;
    }

    function unlock(uint256 tokenId) external onlyRole(LOCK_ROLE) {
        _locked[tokenId] = 0;
    }

    function safeMint(address to, uint256 tokenId, string memory uri, MetaData memory metaData) external onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        // set metadata
        _metaData[tokenId] = metaData;
    }

    // lock forever
    function lockMinter() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _lockMinter = true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        require(_locked[tokenId] == 0, "This token is locked!");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function tokenMetaData(uint256 tokenId) public view returns (MetaData memory)
    {
        return _metaData[tokenId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _grantRole(bytes32 role, address account) internal override {
        require(!_lockMinter || role != MINTER_ROLE, "not allowed!");
        super._grantRole(role, account);
    }
}
