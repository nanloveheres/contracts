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
import "./IFight.sol";
import "./IRandom.sol";

contract GameFi is AdminRole, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    NFT public nft;
    IERC20 public gameToken;
    IERC20 public rewardToken;
    IManager public manager;
    IFight public fight;
    IRandom public rand;

    event Fight(uint256 indexed tokenId, uint256 exp, uint256 reward);

    constructor(
        NFT _nft,
        IERC20 _gameToken,
        IERC20 _rewardToken,
        IManager _manager,
        IFight _fight,
        IRandom _rand
    ) {
        nft = _nft;
        gameToken = _gameToken;
        rewardToken = _rewardToken;
        manager = _manager;
        fight = _fight;
        rand = _rand;
    }

    function migrate(
        NFT _nft,
        IERC20 _gameToken,
        IERC20 _rewardToken,
        IManager _manager,
        IFight _fight,
        IRandom _rand
    ) external onlyOwner {
        nft = _nft;
        gameToken = _gameToken;
        rewardToken = _rewardToken;
        manager = _manager;
        fight = _fight;
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
        uint256 _exp = fight.fightMonster(_tokenId, _monsterId);
        console.log("exp: %s", _exp);
        uint256 _rewardAmount = _exp * fight.getRewardRatio(_monsterId);

        emit Fight(_tokenId, _exp, _rewardAmount);

        if (_exp == 0) {
            // lose
            return;
        }

        nft.exp(_tokenId, _exp);
        rewardToken.transfer(_msgSender(), _rewardAmount);
    }

    // emergency functions

    function emergencyWithdraw() external onlyOwner {
        gameToken.transfer(_msgSender(), gameToken.balanceOf(address(this)));
        rewardToken.transfer(_msgSender(), rewardToken.balanceOf(address(this)));
    }
}
