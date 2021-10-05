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
import "./IManager.sol";
import "./IRandom.sol";

contract GameFi is AdminRole, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    NFT public nft;
    IERC20 public gameToken;
    IERC20 public rewardToken;
    IManager public manager;
    IRandom public rand;

    mapping(uint256 => uint256) public lastFightTimes;

    struct Monster {
        uint256 level;
        uint256 winRate;
        uint256 reward;
        uint256 exp;
    }

    constructor(
        NFT _nft,
        IERC20 _gameToken,
        IERC20 _rewardToken,
        IManager _manager,
        IRandom _rand
    ) {
        nft = _nft;
        gameToken = _gameToken;
        rewardToken = _rewardToken;
        manager = _manager;
        rand = _rand;
    }

    function migrate(
        NFT _nft,
        IERC20 _gameToken,
        IERC20 _rewardToken,
        IManager _manager,
        IRandom _rand
    ) external onlyOwner {
        nft = _nft;
        gameToken = _gameToken;
        rewardToken = _rewardToken;
        manager = _manager;
        rand = _rand;
    }

    modifier onlyNFTOwner(uint256 _tokenId) {
        require(nft.ownerOf(_tokenId) == _msgSender(), "not nft owner");
        _;
    }

    function layEgg(uint8[] memory tribes) external nonReentrant {
        require(tribes.length > 0, "wrong tribes");
        uint256 _amount = manager.feeLayEgg() * tribes.length;
        console.log("$egg:    %s", _amount);
        console.log("$sender: %s", gameToken.balanceOf(_msgSender()));
        gameToken.safeTransferFrom(_msgSender(), manager.feeAddress(), _amount);
        console.log("$sender: %s", gameToken.balanceOf(_msgSender()));
        console.log("$this:   %s", gameToken.balanceOf(manager.feeAddress()));
        nft.layEgg(_msgSender(), tribes);
    }

    function hatch(uint256 _tokenId) external nonReentrant onlyNFTOwner(_tokenId) {
        gameToken.safeTransferFrom(_msgSender(), manager.feeAddress(), manager.feeEvolve());
        uint256 _dna = rand.generate(_tokenId) % (2**32);
        nft.hatch(_tokenId, _dna);
    }

    function changeTribe(uint256 _tokenId, uint8 _tribe) external nonReentrant onlyNFTOwner(_tokenId) {
        gameToken.transferFrom(_msgSender(), manager.feeAddress(), manager.feeChangeTribe());
        nft.changeTribe(_tokenId, _tribe);
    }

    function upgradeGeneration(uint256 _tokenId) external nonReentrant onlyNFTOwner(_tokenId) {
        gameToken.transferFrom(_msgSender(), manager.feeAddress(), manager.feeUpgradeGeneration());
        nft.upgradeGeneration(_tokenId);
    }

    function fightMonster(uint256 _tokenId, uint256 _monsterId) external nonReentrant onlyNFTOwner(_tokenId) {
        uint256 _exp = 1000;
        nft.exp(_tokenId, _exp);
    }

    // emergency functions

    function emergencyWithdraw() external onlyOwner {
        gameToken.transfer(_msgSender(), gameToken.balanceOf(address(this)));
    }
}
