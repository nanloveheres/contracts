//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../utils/AdminRole.sol';

contract RewardToken is ERC20, AdminRole {
    uint256 private constant INITIAL_SUPPLY = 10**8 * (10**18);

    bytes32 public constant MINTER_ROLE = keccak256('MINTER');

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    constructor() ERC20('Daphne', 'DPN') {
        _setRoleAdmin(MINTER_ROLE, OWNER_ROLE);
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function addMinter(address account) public onlyOwner {
        grantRole(MINTER_ROLE, account);
        emit MinterAdded(account);
    }

    function removeMinter(address account) public onlyOwner {
        revokeRole(MINTER_ROLE, account);
        emit MinterRemoved(account);
    }

    function mint(address account, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }
}
