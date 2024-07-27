// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract ERC20Token is ERC20("", ""), Ownable(msg.sender) {
    uint256 public perMint;
    uint256 public price;

    function initialize(
        string memory symbol,
        uint256 _totalSupply,
        uint256 _preMint,
        uint256 _price
    ) public {
        require(totalSupply() == 0, "Already initialized");
    }
}

contract ERC20Factory {
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) public {}
}
