//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';

abstract contract AdminRole is AccessControl {
    // the super admin can assign someone to be a genneral admin role
    bytes32 public constant SUPER_ROLE = keccak256('SUPER');
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN');

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    constructor() {
        _setupRole(SUPER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, SUPER_ROLE);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), 'sender is not an admin');
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function addAdmin(address account) public onlyRole(SUPER_ROLE) {
        grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    function removeAdmin(address account) public onlyRole(SUPER_ROLE) {
        revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    function close() public payable onlyRole(SUPER_ROLE) {
        selfdestruct(payable(msg.sender));
    }
}
