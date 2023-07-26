// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC721A } from "erc721a/contracts/ERC721A.sol";

contract SomeERC721 is ERC721A {
    constructor() ERC721A("Some ERC721A", "SOME") { }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
