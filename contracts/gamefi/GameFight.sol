// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "hardhat/console.sol";
import "../utils/AdminRole.sol";
import "./IFight.sol";
import "./IRandom.sol";
import "./NFT.sol";

contract GameFight is IFight, AdminRole {
    uint256 constant DECIMALS = 10**18;
    uint256 constant REWARD_RATIO = 1 * DECIMALS;
    
    mapping(uint256 => FightItem) public fightMap; // tokenId => last fight time
    struct FightItem {
        uint256 time; //last fight time
        uint8 num; // number of fight quote
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

        addMonster(1, 80, REWARD_RATIO, 5, 10);
        addMonster(2, 70, REWARD_RATIO, 15, 30);
        addMonster(3, 60, REWARD_RATIO, 20, 40);
        addMonster(4, 20, REWARD_RATIO, 60, 120);
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

    modifier onlyBattlefield() {
        require(manager.battlefields(msg.sender), "require Battlefield.");
        _;
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

    function fightMonster(uint256 _tokenId, uint256 _monsterId) external override onlyBattlefield returns (uint256) {
        uint8 _rare = nft.rare(_tokenId);
        require(_rare > 0, "wrong nft id");
        require(_monsterId < monsters.length, "wrong monster id");

        uint256 remainingFightNum = getRemainingFightNum(_tokenId);
        require(remainingFightNum > 0, "wait for next fight interval");

        // uint256 quote = getFightQuoteNum(_tokenId);

        FightItem storage fightItem = fightMap[_tokenId];
        if (remainingFightNum == 1) {
            // last fight, setup next fight interval, reset the fight num
            fightItem.time = block.timestamp;
            fightItem.num = 0;
        }

        // if (fightItem.num >= quote) {
        //     // new fight interval, reset the fight num
        //     fightItem.time = block.timestamp;
        //     fightItem.num = 0;
        // }

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

    function getRemainingFightNum(uint256 _tokenId) public view returns (uint256) {
        uint8 _rare = nft.rare(_tokenId);
        require(_rare > 0, "wrong nft id");

        uint256 lastFightTime = getLastFightTime(_tokenId);
        if (lastFightTime >= block.timestamp) {
            return 0;
        }

        uint256 interval = (block.timestamp - lastFightTime) / manager.fightTimeInterval();
        if (interval == 0) {
            return 0;
        }

        FightItem memory fightItem = fightMap[_tokenId];
        uint256 quote = getFightQuoteNum(_tokenId);

        return (fightItem.num < quote ? quote - fightItem.num : quote);
    }

    function getFightQuoteNum(uint256 _tokenId) public view returns (uint256) {
        uint8 _rare = nft.rare(_tokenId);
        require(_rare > 0, "wrong nft id");

        uint256 lastFightTime = getLastFightTime(_tokenId);
        uint256 interval = (block.timestamp - lastFightTime) / manager.fightTimeInterval();
        uint256 quote = interval <= 1 ? _rare : _rare * interval;
        uint256 maxFightNum = getMaxFightNum(_rare);

        return quote > maxFightNum ? maxFightNum : quote;
    }

    function getMaxFightNum(uint256 _rare) public pure returns (uint256) {
        return _rare * 2;
    }

    function getLastFightTime(uint256 _tokenId) public view returns (uint256) {
        FightItem memory fightItem = fightMap[_tokenId];
        // once born, it can fight
        return (fightItem.time > 0 ? fightItem.time : nft.bornTime(_tokenId) - manager.fightTimeInterval());
    }
}
