//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract AdminRole is AccessControl {
    // the owner can assign someone to be an admin
    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    event RoleAdded(string indexed role, address indexed account);
    event RoleRemoved(string indexed role, address indexed account);

    address public owner;

    constructor() {
        owner = msg.sender;
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
    }

    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender), "sender is not an owner");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function addAdmin(address account) public onlyRole(OWNER_ROLE) {
        grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    function removeAdmin(address account) public onlyRole(OWNER_ROLE) {
        revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    function newRole(string memory role) public onlyRole(OWNER_ROLE) {
        _newRole(role);
    }

    function _newRole(string memory role) internal virtual {
        bytes32 byteRole = keccak256(bytes(role));
        _setupRole(byteRole, msg.sender);
        _setRoleAdmin(byteRole, OWNER_ROLE);
    }

    function isRole(string memory role, address account) public view returns (bool) {
        return hasRole(keccak256(bytes(role)), account);
    }

    function addRole(string memory role, address account) public onlyRole(OWNER_ROLE) {
        grantRole(keccak256(bytes(role)), account);
        emit RoleAdded(role, account);
    }

    function removeRole(string memory role, address account) public onlyRole(OWNER_ROLE) {
        revokeRole(keccak256(bytes(role)), account);
        emit RoleRemoved(role, account);
    }

    function close() public payable onlyRole(OWNER_ROLE) {
        selfdestruct(payable(msg.sender));
    }
}
