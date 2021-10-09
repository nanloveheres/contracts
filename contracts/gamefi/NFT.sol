// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./IManager.sol";

contract NFT is ERC721Enumerable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum Tribe {
        SKYLER,
        HYDREIN,
        PLASMER,
        STONIC
    }

    event LayEgg(uint256 indexed tokenId, address buyer);
    event Hatch(uint256 indexed tokenId, uint256 dna);
    event UpdateTribe(uint256 indexed tokenId, Tribe tribe);
    event UpgradeGeneration(uint256 indexed tokenId, uint256 newGeneration);
    event Exp(uint256 indexed tokenId, uint256 exp);
    event Farming(uint256 indexed tokenId, uint256 time);

    struct Metadata {
        uint256 generation;
        Tribe tribe;
        uint256 exp;
        uint256 dna;
        uint256 farmTime;
        uint256 bornTime;
    }

    uint256 public latestTokenId;
    uint256 public nftTotalSupply;
    uint256 public nftHoldLimit;
    mapping(uint256 => bool) public isEvolved;

    mapping(uint256 => Metadata) internal heros;

    IManager public manager;
    address public owner;

    constructor(
        string memory _name,
        string memory _symbol,
        IManager _manager
    ) ERC721(_name, _symbol) {
        manager = _manager;
        owner = msg.sender;
        nftTotalSupply = 10000;
        nftHoldLimit = 3;
    }

    function migrate(IManager _manager) external onlyOwner {
        manager = _manager;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "sender is not an owner");
        _;
    }

    modifier onlyFarmer() {
        require(manager.farmOwners(msg.sender), "require Farmer.");
        _;
    }

    modifier onlySpawner() {
        require(manager.spawners(msg.sender), "require Spawner.");
        _;
    }

    modifier onlyBattlefield() {
        require(manager.battlefields(msg.sender), "require Battlefield.");
        _;
    }

    function totalSupply() public view override returns (uint256) {
        return nftTotalSupply;
    }

    function isApprovedForAll(address _owner, address _operator) public view virtual override returns (bool) {
        return manager.markets(_operator) || manager.markets(_owner) || super.isApprovedForAll(_owner, _operator);
    }

    function layEgg(address receiver, uint8[] memory tribes) external onlySpawner {
        require(tribes.length > 0, "require tribes: >0");
        require(_getNextTokenId() <= nftTotalSupply, "All EPets sold out.");
        require(balanceOf(receiver) <= nftHoldLimit, "The number of EPets has reached the maximum");

        for (uint256 index = 0; index < tribes.length; index++) {
            _layEgg(receiver, Tribe(tribes[index]));
        }
    }

    function _layEgg(address receiver, Tribe tribe) internal {
        uint256 nextTokenId = _getNextTokenId();
        _mint(receiver, nextTokenId);

        heros[nextTokenId] = Metadata({ generation: manager.generation(), tribe: tribe, exp: 0, dna: 0, farmTime: 0, bornTime: block.timestamp });

        emit LayEgg(nextTokenId, receiver);
    }

    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);

        _incrementTokenId();
    }

    function hatch(uint256 _tokenId, uint256 _dna) public onlySpawner {
        Metadata storage hero = heros[_tokenId];
        require(!isEvolved[_tokenId], "require: not evolved");

        hero.bornTime = block.timestamp;
        hero.dna = _dna;
        isEvolved[_tokenId] = true;

        emit Hatch(_tokenId, _dna);
    }

    function changeTribe(uint256 _tokenId, uint8 _tribe) external onlySpawner {
        Metadata storage hero = heros[_tokenId];
        hero.tribe = Tribe(_tribe);

        emit UpdateTribe(_tokenId, Tribe(_tribe));
    }

    function upgradeGeneration(uint256 _tokenId) external onlySpawner {
        Metadata storage hero = heros[_tokenId];
        hero.generation += 1;

        emit UpgradeGeneration(_tokenId, hero.generation);
    }

    function exp(uint256 _tokenId, uint256 _exp) public onlyBattlefield {
        require(_exp > 0, "no exp");
        Metadata storage hero = heros[_tokenId];
        hero.exp = hero.exp.add(_exp);
        emit Exp(_tokenId, _exp);
    }

    function farming(uint256 _tokenId, uint256 _time) public onlyFarmer {
        require(_time > 0, "no time");
        Metadata storage hero = heros[_tokenId];
        hero.farmTime = hero.farmTime.add(_time);

        emit Farming(_tokenId, _time);
    }

    /**
     * @dev calculates the next token ID based on value of latestTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return latestTokenId.add(1);
    }

    /**
     * @dev increments the value of latestTokenId
     */
    function _incrementTokenId() private {
        latestTokenId++;
    }

    function getHero(uint256 _tokenId) public view returns (Metadata memory) {
        return heros[_tokenId];
    }

    function bornTime(uint256 _tokenId) public view returns (uint256) {
        return heros[_tokenId].bornTime;
    }

    function level(uint256 _tokenId) public view returns (uint8) {
        return getLevel(getHero(_tokenId).exp);
    }

    function rare(uint256 _tokenId) public view returns (uint8) {
        uint256 dna = getHero(_tokenId).dna;
        if (dna == 0) return 0;
        uint256 rareParser = dna % 10000; // [0, 10000)
        if (rareParser < 10) {
            return 6;
        } else if (rareParser < 110) {
            return 5;
        } else if (rareParser < 610) {
            return 4;
        } else if (rareParser < 1610) {
            return 3;
        } else if (rareParser < 4610) {
            return 2;
        } else {
            return 1;
        }
    }

    function getLevel(uint256 _exp) internal pure returns (uint8) {
        if (_exp < 100) {
            return 1;
        } else if (_exp < 350) {
            return 2;
        } else if (_exp < 1000) {
            return 3;
        } else if (_exp < 2000) {
            return 4;
        } else if (_exp < 4000) {
            return 5;
        } else {
            return 6;
        }
    }

    function setNFTTotalSupply(uint256 _totalSupply) external onlyOwner {
        nftTotalSupply = _totalSupply;
    }

    function setNFTHoldLimit(uint256 _nftHoldLimit) external onlyOwner {
        nftHoldLimit = _nftHoldLimit;
    }
}
