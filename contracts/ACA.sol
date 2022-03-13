// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ACA is ERC20 {
    constructor() ERC20("AdvancedContractAll", "ACA") {
        _mint(msg.sender, 100000000);
    }
    
        	function mint(address account,uint256 amount) public onlyOwner{
        		_mint(account, amount);}
        

    
        	function burn(address account, uint256 amount) public onlyOwner {
        		_burn(account, amount);}
        

    
}