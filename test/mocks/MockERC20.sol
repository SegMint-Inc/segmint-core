// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Some ERC20", "SOME") { }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
