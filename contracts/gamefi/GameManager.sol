// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./IManager.sol";
import "../utils/AdminRole.sol";

contract GameManager is IManager, AdminRole {
    // bytes32 public constant BATTLE_ROLE = keccak256("BATTLE");
    // bytes32 public constant EVOLVER_ROLE = keccak256("EVOLVER");
    // bytes32 public constant MARKET_ROLE = keccak256("MARKET");
    // bytes32 public constant FARM_ROLE = keccak256("FARM");

    mapping(uint256 => uint256) public timesBattleMap;
    mapping(string => uint256) public propsU256;
    address _feeAddress = address(this);

    constructor() {
        _newRole("BATTLE");
        _newRole("EVOLVER");
        _newRole("MARKET");
        _newRole("FARM");
        // _setupRole(BATTLE_ROLE, msg.sender);
        // _setupRole(EVOLVER_ROLE, msg.sender);
        // _setupRole(MARKET_ROLE, msg.sender);
        // _setupRole(FARM_ROLE, msg.sender);
        // _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        // _setRoleAdmin(EVOLVER_ROLE, OWNER_ROLE);
        // _setRoleAdmin(MARKET_ROLE, OWNER_ROLE);
        // _setRoleAdmin(FARM_ROLE, OWNER_ROLE);
    }

    function battlefields(address _address) external view override returns (bool) {
        return isRole("BATTLE", _address);
    }

    function evolvers(address _address) external view override returns (bool) {
        return isRole("EVOLVER", _address);
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

    function setTimesBattle(uint256 level, uint256 times) external payable onlyOwner {
        timesBattleMap[level] = times;
    }

    function setPropsU256(string memory name, uint256 value) external payable onlyOwner {
        propsU256[name] = value;
    }

    function setFeeAddress(address _address) external payable onlyOwner {
        _feeAddress = _address;
    }
}