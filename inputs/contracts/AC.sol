// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AC is ERC20 {
    constructor() ERC20("AdvancedContract", "AC") {
        _mint(msg.sender, 100000000);
    }
    
    
    
}