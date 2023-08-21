// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISegMintVaultSingle } from "./interfaces/ISegMintVaultSingle.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { Errors } from "./libraries/Errors.sol";
import { AssetType, Vault, Keys } from "./types/DataTypes.sol";

/**
 * @title SegMintVaultSingle
 * @notice See documentation for {ISegMintVaultSingle}.
 */

contract SegMintVaultSingle is ISegMintVaultSingle, Initializable {
    /// @dev Interface of SegMint Keys contract.
    ISegMintKeys public keys;

    /// @dev The asset deposited.
    Vault.Asset public asset;

    /// @dev Key bindings associated with this vault.
    Keys.Bindings public keyBindings;

    /**
     * @inheritdoc ISegMintVaultSingle
     */
    function initialize(ISegMintKeys keys_, Vault.Asset calldata asset_, Keys.Bindings calldata keyBindings_)
        external
        initializer
    {
        keys = keys_;
        asset = asset_;
        keyBindings = keyBindings_;
    }

    /**
     * Function used to unlock an asset from a vault using keys.
     * @param receiver Receiver of the unlocked asset.
     */
    function unlockAsset(address receiver) external {
        /// Copy `asset` struct into memory to avoid SLOADs.
        Vault.Asset memory _asset = asset;

        /// Checks: Ensure that the asset has not already been unlocked.
        if (_asset.assetType == AssetType.NONE) revert Errors.NoAssetLocked();

        /// Copy `keyBindings` struct into memory to avoid SLOADs.
        Keys.Bindings memory _keyBindings = keyBindings;

        /// Checks: Ensure the caller holds all keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBindings.keyId);
        if (keysHeld != _keyBindings.amount) revert Errors.InsufficientKeys();

        /// Clear `asset` struct in storage.
        asset = Vault.Asset({ assetType: AssetType.NONE, token: address(0), identifier: 0, amount: 0 });

        /// Clear `keyBindings` struct in storage.
        keyBindings = Keys.Bindings({ binded: false, keyId: 0, amount: 0 });

        /// Burn the keys associated with the vault.
        keys.burnKeys(msg.sender, _keyBindings.keyId, _keyBindings.amount);

        /// Transfer asset to the receiver.
        /// forgefmt: disable-next-item
        if (_asset.assetType == AssetType.ERC721) {
            IERC721(_asset.token).safeTransferFrom({
                from: address(this),
                to: receiver,
                tokenId: _asset.identifier
            });
        } else {
            IERC1155(_asset.token).safeTransferFrom({
                from: address(this),
                to: receiver,
                id: _asset.identifier,
                value: _asset.amount,
                data: ""
            });
        }

        /// Emit key burn event.
        emit ISegMintVaultSingle.KeysBurned({
            vault: address(this),
            keyId: _keyBindings.keyId,
            amount: _keyBindings.amount
        });
    }

    /**
     * See {IERC721.onERC721Received}.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * See {IERC1155.onERC1155Received}.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
