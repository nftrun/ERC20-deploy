// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IRefStore.sol";

contract RefStore is IRefStore, AccessControl {
    uint32 private _open = 1;
    bytes32 public constant APPEND_ROLE = keccak256("APPEND_ROLE");
    /// @dev referrer[user] => user
    mapping(address => address) public override referrer;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(APPEND_ROLE, admin);
    }

    ///
    function addReferrer(address from, address to) external override {
        require(referrer[from] == address(0), 'alreday add!');
        require(hasRole(APPEND_ROLE, msg.sender), "access denied!");
        referrer[from] = to;
        emit ReferrerAdded(to, from);
    }

    function addReferrerWithCheck(address to) external override {
        require(_open == 1, 'access denied!');
        require(referrer[msg.sender] == address(0), 'alreday add!');
        require(referrer[to] != address(0), 'invalid to!');
        referrer[msg.sender] = to;
        emit ReferrerAdded(to, msg.sender);
    }

    function forceSetReferrer(address from, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        referrer[from] = to;
        emit ReferrerAdded(to, from);
    }

    function open() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _open = 1;
    }

    function close() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _open = 0;
    }
}