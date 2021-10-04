// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "../utils/AdminRole.sol";
import "./NFT.sol";

contract GameFi is AdminRole, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    NFT public nft;
    IERC20 public gameToken;
    IERC20 public rewardToken;

    constructor(
        NFT _nft,
        IERC20 _gameToken,
        IERC20 _rewardToken
    ) {
        nft = _nft;
        gameToken = _gameToken;
        rewardToken = _rewardToken;
    }

    function migrate(
        NFT _nft,
        IERC20 _gameToken,
        IERC20 _rewardToken
    ) external onlyOwner {
        nft = _nft;
        gameToken = _gameToken;
        rewardToken = _rewardToken;
    }

    function layEgg(uint8[] memory tribes) external nonReentrant {
        uint256 _amount = nft.priceEgg();        
        gameToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        nft.layEgg(msg.sender, tribes);
    }
}
