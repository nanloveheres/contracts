//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '../utils/AdminRole.sol';

contract ExampleAdminRole is AdminRole {
    constructor(address super_admin) {
        _setupRole(OWNER_ROLE, super_admin);
    }

    receive() external payable {}
}
