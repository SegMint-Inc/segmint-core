// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ERC1155, ERC1155Burnable } from "@openzeppelin/token/ERC1155/extensions/ERC1155Burnable.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";

contract SegMintKeys is ISegMintKeys, OwnableRoles, ERC1155Burnable {
    ISegMintKYCRegistry public kycRegistry;

    constructor(address admin_, string memory uri_, ISegMintKYCRegistry kycRegistry_) ERC1155(uri_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);
        kycRegistry = kycRegistry_;
    }

    function createKeys(address receiver) external { }
}
