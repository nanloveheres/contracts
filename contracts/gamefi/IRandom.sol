// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRandom {
    function generate(uint256 salt) external view returns (uint256);
}