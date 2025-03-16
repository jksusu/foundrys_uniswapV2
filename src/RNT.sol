// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RNT is ERC20 {
    constructor() ERC20("RNT", "RNT") {
        _mint(msg.sender, 1e10 * 1e18);
    }
}
