/**
 *Submitted for verification at Etherscan.io on 2022-12-28
*/

/**
 *Submitted for verification at Etherscan.io on 2022-05-16
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.2;

contract ERC20 {

    string public constant name = "VentiSwap Token";
    string public constant symbol = "VST";
    uint8 public constant decimals = 18;  
    uint256 public constant totalSupply = 100000000000000000000000000;

 
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);


    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;
    
   constructor() public {  
	balances[msg.sender] = 100000000000000000000000000;
    }  

 
    function balanceOf(address tokenOwner) external view returns (uint) {
        return balances[tokenOwner];
    }
     function tokenRemaning(address token) external view returns (uint) {
        return balances[token];
}
    function transfer(address receiver, uint numTokens) public returns (bool) {
       uint OwnerBalance=balances[msg.sender];
        require(numTokens <= OwnerBalance ,"Don't have enough Tokens...");
        
        balances[msg.sender] = OwnerBalance-numTokens;
        balances[receiver]+=numTokens;
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) external returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) external view returns (uint) {
        return allowed[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
       uint OwnerBalance=balances[owner];
       uint AlowedOwner=allowed[owner][msg.sender];

        require(numTokens <= OwnerBalance,"Don't have enough Tokens...");    
        require(numTokens <= AlowedOwner);
    
        balances[owner] = OwnerBalance-numTokens;
        allowed[owner][msg.sender] =AlowedOwner-numTokens;
        balances[buyer] +=numTokens;
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}