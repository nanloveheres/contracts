// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "hardhat/console.sol";
import "../utils/AdminRole.sol";
import "./IFight.sol";
import "./IRandom.sol";
import "./NFT.sol";

contract GameFight is IFight, AdminRole {
    mapping(uint256 => FightItem) public fightMap; // tokenId => last fight time
    struct FightItem {
        uint256 time; //last fight time
        uint8 num; // number of fight
    }

    struct Monster {
        uint8 level;
        uint256 winRate;
        uint256 rewardRatio;
        uint256 lowExp;
        uint256 highExp;
    }

    Monster[] public monsters;

    NFT public nft;
    IManager public manager;
    IRandom public rand;

    constructor(
        NFT _nft,
        IManager _manager,
        IRandom _rand
    ) {
        nft = _nft;
        manager = _manager;
        rand = _rand;

        addMonster(1, 80, 1 ether, 5, 10);
        addMonster(1, 70, 1 ether, 15, 30);
        addMonster(1, 60, 1 ether, 20, 40);
        addMonster(1, 20, 1 ether, 60, 120);
    }

    function migrate(
        NFT _nft,
        IManager _manager,
        IRandom _rand
    ) external onlyOwner {
        nft = _nft;
        manager = _manager;
        rand = _rand;
    }

    function addMonster(
        uint8 _level,
        uint256 _winRate,
        uint256 _rewardRatio,
        uint256 _lowExp,
        uint256 _highExp
    ) public onlyOwner {
        require(_highExp > _lowExp, "wrong exp");
        monsters.push(Monster({ level: _level, winRate: _winRate, rewardRatio: _rewardRatio, lowExp: _lowExp, highExp: _highExp }));
    }

    function updateMonster(
        uint256 _monsterId,
        uint8 _level,
        uint256 _winRate,
        uint256 _rewardRatio,
        uint256 _lowExp,
        uint256 _highExp
    ) public onlyOwner {
        require(_monsterId < monsters.length, "wrong monster id");
        require(_highExp > _lowExp, "wrong exp");
        Monster storage _monster = monsters[_monsterId];
        _monster.level = _level;
        _monster.winRate = _winRate;
        _monster.rewardRatio = _rewardRatio;
        _monster.lowExp = _lowExp;
        _monster.highExp = _highExp;
    }

    function getMonster(uint256 _monsterId) public view returns (Monster memory) {
        return monsters[_monsterId];
    }

    function getRewardRatio(uint256 _monsterId) external view override returns (uint256) {
        return monsters[_monsterId].rewardRatio;
    }

    function fightMonster(uint256 _tokenId, uint256 _monsterId) external override returns (uint256) {
        uint8 _rare = nft.rare(_tokenId);
        require(_rare > 0, "wrong nft id");
        require(_monsterId < monsters.length, "wrong monster id");

        FightItem storage fightItem = fightMap[_tokenId];
        bool timeAllowed = (block.timestamp - fightItem.time >= manager.fightTimeInterval());
        require(timeAllowed || fightItem.num < _rare, "wait for next fight interval");
        fightItem.time = block.timestamp;

        if (fightItem.num >= _rare && timeAllowed) {
            // new fight interval, reset the fight num
            fightItem.num = 0;
        }

        fightItem.num += 1;
        Monster memory _monster = monsters[_monsterId];
        uint256 _fightRatio = rand.generate(_tokenId + _monsterId) % 100;

        console.log("fightRatio: %s", _fightRatio);

        if (_fightRatio > _monster.winRate) {
            // lose! as the fight ratio is out of win%
            return 0;
        }

        // calculate exp
        return _monster.lowExp + (_fightRatio * (_monster.highExp - _monster.lowExp)) / _monster.winRate;
    }
}
