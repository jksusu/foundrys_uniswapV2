// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RntToken is ERC20 {
    // 可以添加一个constant或immutable变量来定义总供应量，使代码更清晰NT") {
    uint256 public constant TOTAL_SUPPLY = 1e10 * 1e18;

    constructor() ERC20("RNT", "RNT") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
