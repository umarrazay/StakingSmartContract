// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RWT is ERC20, Ownable {
    constructor() ERC20("RewardToken", "RWT") {
        // _mint(msg.sender, 100000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external  {
        _mint(to, amount);
    }
}


// mint the token upon claiming rewards to the user address