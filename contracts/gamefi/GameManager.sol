// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IManager.sol";
import "../utils/AdminRole.sol";

contract GameManager is IManager, AdminRole {
    mapping(uint256 => uint256) public timesBattleMap;
    mapping(string => uint256) public propsU256;
    mapping(string => uint256) public feeSettingU256;
    address _feeAddress = address(this);
    address _techProfitAddress = address(this);
    uint256 constant DECIMALS = 10**18;

    constructor() {
        _newRole("BATTLE");
        _newRole("SPAWN");
        _newRole("MARKET");
        _newRole("FARM");
        propsU256["feeMarketRate"] = 300; //3%
        propsU256["divPercent"] = 10000;
        propsU256["feeLayEgg"] = 1000 * DECIMALS;
        propsU256["feeChangeTribe"] = 1 * DECIMALS;
        propsU256["feeUpgradeGeneration"] = 500 * DECIMALS;
        propsU256["feeEvolve"] = 6000 * DECIMALS;
        propsU256["loseRate"] = 300;
        propsU256["fightTimeInterval"] = 4 hours;
        feeSettingU256["brunFeeRate"] = 60; //60%;
        feeSettingU256["foundationFeeRate"] = 20; //20%;
        feeSettingU256["inviteeFeeRate"] = 10; //10%;
        feeSettingU256["techFeeRate"] = 10; //10%;
    }

    function battlefields(address _address) external view override returns (bool) {
        return isRole("BATTLE", _address);
    }

    function spawners(address _address) external view override returns (bool) {
        return isRole("SPAWN", _address);
    }

    function markets(address _address) external view override returns (bool) {
        return isRole("MARKET", _address);
    }

    function farmOwners(address _address) external view override returns (bool) {
        return isRole("FARM", _address);
    }

    function timesBattle(uint256 level) external view override returns (uint256) {
        return timesBattleMap[level];
    }

    function timeLimitBattle() external view override returns (uint256) {
        return propsU256["timeLimitBattle"];
    }

    function generation() external view override returns (uint256) {
        return propsU256["generation"];
    }

    function xBattle() external view override returns (uint256) {
        return propsU256["xBattle"];
    }

    function feeLayEgg() external view override returns (uint256) {
        return propsU256["feeLayEgg"];
    }

    function divPercent() external view override returns (uint256) {
        return propsU256["divPercent"];
    }

    function feeUpgradeGeneration() external view override returns (uint256) {
        return propsU256["feeUpgradeGeneration"];
    }

    function feeChangeTribe() external view override returns (uint256) {
        return propsU256["feeChangeTribe"];
    }

    function feeMarketRate() external view override returns (uint256) {
        return propsU256["feeMarketRate"];
    }

    function loseRate() external view override returns (uint256) {
        return propsU256["loseRate"];
    }

    function feeEvolve() external view override returns (uint256) {
        return propsU256["feeEvolve"];
    }

    function feeAddress() external view override returns (address) {
        return _feeAddress;
    }

    function techProfitAddress() external view override returns (address) {
        return _techProfitAddress;
    }

    function fightTimeInterval() external view override returns (uint256) {
        return propsU256["fightTimeInterval"];
    }

    function setTimesBattle(uint256 level, uint256 times) external payable onlyOwner {
        timesBattleMap[level] = times;
    }

    function setPropsU256(string memory name, uint256 value) external payable onlyOwner {
        propsU256[name] = value;
    }

    function setFeeAddress(address _address) external payable onlyOwner {
        _feeAddress = _address;
    }

    function setTechProfitAddress(address _address) external payable onlyOwner {
        _techProfitAddress = _address;
    }

    function setFeeSettingU256(string memory name, uint256 value) external onlyOwner {
        feeSettingU256[name] = value;
    }

    function techFeeRate() external view override returns (uint256) {
        return feeSettingU256["techFeeRate"];
    }

    function inviteeFeeRate() external view override returns (uint256) {
        return feeSettingU256["inviteeFeeRate"];
    }

    function brunFeeRate() external view override returns (uint256) {
        return feeSettingU256["brunFeeRate"];
    }

    function foundationFeeRate() external view override returns (uint256) {
        return feeSettingU256["foundationFeeRate"];
    }
}
