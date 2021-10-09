// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "hardhat/console.sol";
import "../utils/AdminRole.sol";
import "./NFT.sol";

contract NFTMarket is AdminRole {
    using EnumerableSet for EnumerableSet.UintSet;

    struct ItemSale {
        uint256 tokenId;
        address owner;
        uint256 price;
    }

    mapping(uint256 => ItemSale) internal markets;

    EnumerableSet.UintSet private tokenSales;
    mapping(address => EnumerableSet.UintSet) private sellerTokens;

    event PlaceOrder(uint256 indexed tokenId, address seller, uint256 price);
    event CancelOrder(uint256 indexed tokenId, address seller);
    event UpdatePrice(uint256 indexed tokenId, address seller, uint256 newPrice);
    event FillOrder(uint256 indexed tokenId, address seller);

    NFT public nft;
    IERC20 public gameToken;
    IManager public manager;

    constructor(
        NFT _nft,
        IERC20 _gameToken,
        IManager _manager
    ) {
        nft = _nft;
        gameToken = _gameToken;
        manager = _manager;
    }

    function migrate(
        NFT _nft,
        IERC20 _gameToken,
        IManager _manager
    ) external onlyOwner {
        nft = _nft;
        gameToken = _gameToken;
        manager = _manager;
    }

    function placeOrder(uint256 _tokenId, uint256 _price) external {
        require(nft.ownerOf(_tokenId) == _msgSender(), "not own");
        require(_price > 0, "nothing is free");

        // note: sender has to approve his nft to the market address
        nft.transferFrom(_msgSender(), address(this), _tokenId);
        tokenSales.add(_tokenId);
        sellerTokens[_msgSender()].add(_tokenId);
        markets[_tokenId] = ItemSale({ tokenId: _tokenId, price: _price, owner: _msgSender() });

        emit PlaceOrder(_tokenId, _msgSender(), _price);
    }

    function cancelOrder(uint256 _tokenId) external {
        require(tokenSales.contains(_tokenId), "not sale");
        ItemSale memory itemSale = markets[_tokenId];
        require(itemSale.owner == _msgSender(), "not own");

        nft.transferFrom(address(this), _msgSender(), _tokenId);
        tokenSales.remove(_tokenId);
        sellerTokens[itemSale.owner].remove(_tokenId);

        emit CancelOrder(_tokenId, _msgSender());
    }

    function updatePrice(uint256 _tokenId, uint256 _price) external {
        require(tokenSales.contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_tokenId];
        require(itemSale.owner == _msgSender(), "not own");
        require(_price > 0, "nothing is free");

        itemSale.price = _price;

        emit UpdatePrice(_tokenId, _msgSender(), _price);
    }

    function fillOrder(uint256 _tokenId) external {
        require(tokenSales.contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_tokenId];
        uint256 feeMarket = (itemSale.price * manager.feeMarketRate()) / manager.divPercent();
        gameToken.transferFrom(_msgSender(), manager.feeAddress(), feeMarket);
        gameToken.transferFrom(_msgSender(), itemSale.owner, itemSale.price - feeMarket);

        nft.transferFrom(address(this), _msgSender(), _tokenId);
        tokenSales.remove(_tokenId);
        sellerTokens[itemSale.owner].remove(_tokenId);

        emit FillOrder(_tokenId, _msgSender());
    }

    function marketSize() public view returns (uint256) {
        return tokenSales.length();
    }

    function orders(address _seller) public view returns (uint256) {
        return sellerTokens[_seller].length();
    }

    function tokenSaleByIndex(uint256 index) public view returns (uint256) {
        return tokenSales.at(index);
    }

    function tokenSaleOfOwnerByIndex(address _seller, uint256 index) public view returns (uint256) {
        return sellerTokens[_seller].at(index);
    }

    function getSale(uint256 _tokenId) public view returns (ItemSale memory) {
        if (tokenSales.contains(_tokenId)) {
            return markets[_tokenId];
        }

        return ItemSale({ tokenId: 0, owner: address(0), price: 0 });
    }
}
