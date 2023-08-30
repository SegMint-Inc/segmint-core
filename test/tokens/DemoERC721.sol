// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC721A } from "erc721a/contracts/ERC721A.sol";

contract DemoERC721 is ERC721A {
    constructor() ERC721A("Demo ERC721A", "DEMO") { }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
