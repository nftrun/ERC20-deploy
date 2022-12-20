// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IRefStore {
    /// referrer
    function referrer(address from) external view returns (address);
    /// add referrer
    function addReferrer(address from, address to) external;
    function addReferrerWithCheck(address to) external;
    function open() external;
    function close() external;
    /// referrer added
    event ReferrerAdded(address indexed to, address from);
}