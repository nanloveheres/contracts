// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFight {
    function getRewardRatio(uint256 _monsterId) external view returns (uint256);
    function fightMonster(uint256 _tokenId, uint256 _monsterId) external returns (uint256);
}