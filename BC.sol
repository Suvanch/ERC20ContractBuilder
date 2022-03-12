// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BC is ERC20 {
    constructor() ERC20("BasicContract", "BC") {
        _mint(msg.sender, 100000000);
    }
}