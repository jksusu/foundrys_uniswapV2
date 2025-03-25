// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20TOKEN is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1e10 * 1e18;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
