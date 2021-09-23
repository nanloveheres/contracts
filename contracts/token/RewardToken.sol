//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeToken.sol";

contract RewardToken is SafeToken {
    uint256 private constant INITIAL_SUPPLY = 10**8 * (10**18);

    constructor() SafeToken("Daphne Finance", "DPN", INITIAL_SUPPLY) {}
}
