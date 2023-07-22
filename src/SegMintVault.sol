// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISegMintVault } from "./interfaces/ISegMintVault.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { Errors } from "./libraries/Errors.sol";
import { Vault } from "./types/DataTypes.sol";

contract SegMintVault is ISegMintVault, Ownable {
    /**
     * In this context, the `owner_` address will be the {SegMintVaultManager}.
     */
    constructor(address owner_) {
        _initializeOwner(owner_);
    }

    function lockAssets(Vault.Asset[] calldata assets) external payable onlyOwner { }

    function lockAssetsForKeys(Vault.Asset[] calldata assets) external payable onlyOwner { }

    function unlockAssets(Vault.Asset[] calldata assets, address receiver) external onlyOwner { }

    function unlockAssetsWithKeys(Vault.Asset[] calldata assets, address receiver) external onlyOwner { }
}
