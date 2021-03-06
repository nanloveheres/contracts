// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IManager {
    function battlefields(address _address) external view returns (bool);

    function spawners(address _address) external view returns (bool);

    function markets(address _address) external view returns (bool);

    function farmOwners(address _address) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function generation() external view returns (uint256);

    function xBattle() external view returns (uint256);

    function feeLayEgg() external view returns (uint256);

    function divPercent() external view returns (uint256);

    function feeUpgradeGeneration() external view returns (uint256);

    function feeChangeTribe() external view returns (uint256);

    function feeMarketRate() external view returns (uint256);

    function loseRate() external view returns (uint256);

    function feeEvolve() external view returns (uint256);

    function feeAddress() external view returns (address);

    function techProfitAddress() external view returns (address);

    function fightTimeInterval() external view returns (uint256);

    function techFeeRate() external view returns (uint256);

    function inviteeFeeRate() external view returns (uint256);

    function brunFeeRate() external view returns (uint256);

    function foundationFeeRate() external view returns (uint256);
}
