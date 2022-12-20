// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IRunbit.sol";

contract RunbitRand is AccessControl {
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    IDataFeed oracle;
    uint256 epoch = 86400;

    mapping(uint256 => uint256) randCommit;
    mapping(uint256 => uint256) randSeed;
    mapping(uint256 => uint256) rands;
    

    function setCommit(uint256 commit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 day = _day();
        require(randCommit[day] == 0, "E01: alreay set!");
        randCommit[day] = commit;
    }
    
    function setSeed() external {
        uint256 day = _day() - 1;
        require(randSeed[day] == 0, "E01: alreay set!");
        randSeed[day] = uint256(keccak256(abi.encodePacked(block.coinbase, gasleft(), block.timestamp, blockhash(block.number - 1), oracle.latestAnswer())));
    }

    function genRand(uint256 sec) external {
        uint256 day = _day() - 1;
        require(randCommit[day] != 0, "commit not set!");
        require(randSeed[day] != 0, "seed not set!");
        require(randCommit[day] == uint256(keccak256(abi.encodePacked(sec))), "invalid sec!");
        rands[day] = uint256(keccak256(abi.encodePacked(sec, randSeed[day])));

    }
    
    function getRand(uint256 round) external view returns (uint256) {
        return rands[round];
    }

    function genNormalRand() external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.coinbase, gasleft(), block.timestamp, blockhash(block.number - 1), oracle.latestAnswer())));
    }

    function setOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oracle = IDataFeed(_oracle);
    }

    function setEpoch(uint256 _epoch) external onlyRole(DEFAULT_ADMIN_ROLE) {
        epoch = _epoch;
    }

    function _day() private view returns (uint256) {
        return (block.timestamp + 28800) / epoch;
    }
}