// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IManager.sol";

contract NFT is ERC721 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

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
    // event PlaceOrder(uint256 indexed tokenId, address seller, uint256 price);
    // event CancelOrder(uint256 indexed tokenId, address seller);
    // event UpdatePrice(uint256 indexed tokenId, address seller, uint256 newPrice);
    // event FillOrder(uint256 indexed tokenId, address seller);

    struct Metadata {
        uint256 generation;
        Tribe tribe;
        uint256 exp;
        uint256 dna;
        uint256 farmTime;
        uint256 bornTime;
    }

    struct ItemSale {
        uint256 tokenId;
        address owner;
        uint256 price;
    }

    uint256 public latestTokenId;
    uint256 public nftTotalSupply;
    mapping(uint256 => bool) public isEvolved;

    mapping(uint256 => Metadata) internal heros;
    mapping(uint256 => ItemSale) internal markets;

    EnumerableSet.UintSet private tokenSales;
    mapping(address => EnumerableSet.UintSet) private sellerTokens;

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

    function migrate(IManager _manager) external onlyOwner {
        manager = _manager;
    }

    function isApprovedForAll(address _owner, address _operator) public view virtual override returns (bool) {
        return manager.markets(_operator) || manager.markets(_owner) || super.isApprovedForAll(_owner, _operator);
    }

    function layEgg(address receiver, uint8[] memory tribes) external onlySpawner {
        uint256 amount = tribes.length;
        require(amount > 0, "require tribes: >0");
        if (amount == 1) {
            _layEgg(receiver, Tribe(tribes[0]));
        } else {
            for (uint256 index = 0; index < amount; index++) {
                _layEgg(receiver, Tribe(tribes[index]));
            }
        }
    }

    function _layEgg(address receiver, Tribe tribe) internal {
        uint256 nextTokenId = _getNextTokenId();
        require(nextTokenId > nftTotalSupply, "All token sold out.");
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

    function setNFTTotalSupply(uint _totalSupply) external onlyOwner{
        nftTotalSupply = _totalSupply;
    }

    // function placeOrder(uint256 _tokenId, uint256 _price) public {
    //     require(ownerOf(_tokenId) == _msgSender(), "not own");
    //     require(_price > 0, "nothing is free");
    //     require(isEvolved[_tokenId], "require: evolved");

    //     tokenOrder(_tokenId, true, _price);

    //     emit PlaceOrder(_tokenId, _msgSender(), _price);
    // }

    // function cancelOrder(uint256 _tokenId) public {
    //     require(tokenSales.contains(_tokenId), "not sale");
    //     ItemSale storage itemSale = markets[_tokenId];
    //     require(itemSale.owner == _msgSender(), "not own");

    //     tokenOrder(_tokenId, false, 0);

    //     emit CancelOrder(_tokenId, _msgSender());
    // }

    // function updatePrice(uint256 _tokenId, uint256 _price) public {
    //     require(_price > 0, "nothing is free");
    //     require(tokenSales.contains(_tokenId), "not sale");
    //     ItemSale storage itemSale = markets[_tokenId];
    //     require(itemSale.owner == _msgSender(), "not own");

    //     itemSale.price = _price;

    //     emit UpdatePrice(_tokenId, _msgSender(), _price);
    // }

    // function fillOrder(uint256 _tokenId) public {
    //     require(tokenSales.contains(_tokenId), "not sale");
    //     ItemSale storage itemSale = markets[_tokenId];
    //     uint256 feeMarket = itemSale.price.mul(manager.feeMarketRate()).div(manager.divPercent());
    //     gameToken.transferFrom(_msgSender(), manager.feeAddress(), feeMarket);
    //     gameToken.transferFrom(_msgSender(), itemSale.owner, itemSale.price.sub(feeMarket));

    //     tokenOrder(_tokenId, false, 0);
    //     emit FillOrder(_tokenId, _msgSender());
    // }

    // function tokenOrder(
    //     uint256 _tokenId,
    //     bool _sell,
    //     uint256 _price
    // ) internal {
    //     ItemSale storage itemSale = markets[_tokenId];
    //     if (_sell) {
    //         transferFrom(_msgSender(), address(this), _tokenId);
    //         tokenSales.add(_tokenId);
    //         sellerTokens[_msgSender()].add(_tokenId);

    //         markets[_tokenId] = ItemSale({ tokenId: _tokenId, price: _price, owner: _msgSender() });
    //     } else {
    //         transferFrom(address(this), _msgSender(), _tokenId);

    //         tokenSales.remove(_tokenId);
    //         sellerTokens[itemSale.owner].remove(_tokenId);
    //         markets[_tokenId] = ItemSale({ tokenId: 0, price: 0, owner: address(0) });
    //     }
    // }

    // function marketsSize() public view returns (uint256) {
    //     return tokenSales.length();
    // }

    // function orders(address _seller) public view returns (uint256) {
    //     return sellerTokens[_seller].length();
    // }

    // function tokenSaleByIndex(uint256 index) public view returns (uint256) {
    //     return tokenSales.at(index);
    // }

    // function tokenSaleOfOwnerByIndex(address _seller, uint256 index) public view returns (uint256) {
    //     return sellerTokens[_seller].at(index);
    // }

    // function getSale(uint256 _tokenId) public view returns (ItemSale memory) {
    //     if (tokenSales.contains(_tokenId)) return markets[_tokenId];
    //     return ItemSale({ tokenId: 0, owner: address(0), price: 0 });
    // }
}
