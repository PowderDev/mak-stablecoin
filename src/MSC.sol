// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MSC is ERC20Burnable, Ownable {
    constructor() ERC20("MakStablecoin", "MSC") Ownable(msg.sender) {}

    function burn(uint256 amount) public override onlyOwner {
        require(
            amount > 0,
            "MSC: burn amount must be greater than 0"
        );

        uint balance = balanceOf(msg.sender);
        require(
            balance >= amount,
            "MSC: burn amount exceeds balance"
        );

        super.burn(amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(
            amount > 0,
            "MSC: mint amount must be greater than 0"
        );

        require(
            to != address(0),
            "MSC: mint to the zero address"
        );

        _mint(to, amount);
    }
}
