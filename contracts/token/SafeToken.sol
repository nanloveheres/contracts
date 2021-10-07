//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/AdminRole.sol";

contract SafeToken is ERC20, AdminRole {
    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    // Whale Addresses
    mapping(address => bool) private _whales;
    bool public antiWhale = false;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER");

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) {
        _setRoleAdmin(MINTER_ROLE, OWNER_ROLE);
        _mint(msg.sender, initialSupply_);
    }

    function setAntiWhale(bool value) public onlyOwner {
        antiWhale = value;
    }

    function setWhale(address account, bool value) public onlyOwner {
        _whales[account] = value;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (antiWhale) {
            require(!_whales[sender] && !_whales[recipient], "anti whale");
        }
        super._transfer(sender, recipient, amount);
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
