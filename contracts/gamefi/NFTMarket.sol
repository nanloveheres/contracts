// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "../utils/AdminRole.sol";
import "./NFT.sol";

contract NFTMarket is AdminRole {
    NFT public nft;
    IManager public manager;

    event PlaceOrder(uint256 indexed tokenId, address seller, uint256 price);
    event CancelOrder(uint256 indexed tokenId, address seller);
    event UpdatePrice(uint256 indexed tokenId, address seller, uint256 newPrice);
    event FillOrder(uint256 indexed tokenId, address seller);

    constructor(NFT _nft, IManager _manager) {
        nft = _nft;
        manager = _manager;
    }

    function migrate(NFT _nft, IManager _manager) external onlyOwner {
        nft = _nft;
        manager = _manager;
    }



}
