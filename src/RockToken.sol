// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RockToken is ERC20Permit, Ownable {
    constructor()
        ERC20("Rock Token", "ROCK")
        ERC20Permit("Rock Token")
        Ownable(msg.sender)
    {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
