// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract StepCheck is AccessControl {
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    uint256 private _salt = 2023;
    // 周期长度
    uint256 epoch = 86400;
    
    // 步数放在高64位，低192位放hash
    function stepCheck(uint256 checkSum, address user) external view returns (uint256) {
        uint256 day = (block.timestamp + 28800) / epoch;
        uint256 steps = checkSum >> 192;
        uint256 seed = _salt ^ 0x8d2f5a5fb59cea1d0292b88a820aa05b04b4d96fdcadd4f6b86f2938fb651484;
        uint256 hash = uint256(keccak256(abi.encodePacked(steps * steps, user, day * day, seed, (steps << 64) + day)));
        require((checkSum & 0xffffffffffffffffffffffffffffffffffffffffffffffff) == (hash & 0xffffffffffffffffffffffffffffffffffffffffffffffff), "invalid step!");
        return steps;
    }

    function updateSalt(uint256 salt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _salt = salt;
    }

    function setEpoch(uint256 _epoch) external onlyRole(DEFAULT_ADMIN_ROLE) {
        epoch = _epoch;
    }
}