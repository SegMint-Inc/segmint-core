// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";

contract DemoERC1155 is ERC1155 {
    constructor() ERC1155("") { }

    function mint(address receiver, uint256 id, uint256 amount) external {
        _mint(receiver, id, amount, "");
    }
}
