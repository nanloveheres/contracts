// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./IRandom.sol";

contract MockRandom is IRandom {
    uint256 public v;

    function generate(uint256 salt) external view override returns (uint256) {
        return v;
    }

    function setV(uint256 _v) external {
        v = _v;
    }
}
