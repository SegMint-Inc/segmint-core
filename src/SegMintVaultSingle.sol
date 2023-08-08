// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISegMintVaultSingle } from "./interfaces/ISegMintVaultSingle.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { Errors } from "./libraries/Errors.sol";
import { VaultSingle, Keys } from "./types/DataTypes.sol";

/**
 * @title SegMintVault
 * @notice See documentation for {ISegMintVaultSingle}.
 */

contract SegMintVaultSingle is ISegMintVaultSingle, Ownable, Initializable {
    /// @dev Interface of {SegMintKeys}.
    ISegMintKeys public keys;

    /// @dev The asset deposited into this contract.
    VaultSingle.Asset public asset;

    /// @dev Key bindings associated with this vault.
    Keys.Bindings public keyBindings;

    /**
     * @inheritdoc ISegMintVaultSingle
     */
    function initialize(address owner_, ISegMintKeys keys_, VaultSingle.Asset calldata asset_) external initializer {
        _initializeOwner(owner_);
        keys = keys_;
        asset = asset_;
    }

    /**
     * @inheritdoc ISegMintVaultSingle
     * @dev Off-chain indexer will keep track of assets unlocked from a vault using
     * the transfer events emitted from each assets token standard.
     */
    function unlockAsset(address receiver) external override {
        /// Copy asset struct into memory to avoid SLOADs.
        VaultSingle.Asset memory _asset = asset;

        /// Checks: Ensure that the asset has not already been unlocked.
        if (_asset.class == VaultSingle.SingleClass.NONE) revert Errors.NoAssetLocked();

        /// Copy key bindings struct into memory to avoid SLOADs.
        Keys.Bindings memory _keyBindings = keyBindings;

        /// If a vault is key-binded, only the holder of all keys can unlock assets.
        if (_keyBindings.binded) {
            uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBindings.keyId);
            if (keysHeld != _keyBindings.amount) revert Errors.InsufficientKeys();
        } else {
            /// Reverts with `Unauthorized()` if caller is not the owner.
            _checkOwner();
        }

        /// Clear asset struct in storage.
        asset = VaultSingle.Asset({ class: VaultSingle.SingleClass.NONE, addr: address(0), tokenId: 0, amount: 0 });

        /// forgefmt: disable-next-item
        if (_asset.class == VaultSingle.SingleClass.ERC_721) {
            IERC721(_asset.addr).safeTransferFrom({
                from: address(this),
                to: receiver,
                tokenId: _asset.tokenId
            });
        } else {
            IERC1155(_asset.addr).safeTransferFrom({
                from: address(this),
                to: receiver,
                id: _asset.tokenId,
                amount: _asset.amount,
                data: ""
            });
        }
    }

    /**
     * @inheritdoc ISegMintVaultSingle
     * @dev Discuss if there is a key limit.
     */
    function bindKeys(uint256 amount) external override onlyOwner {
        /// Checks: Ensure the vault is not already key-binded.
        if (keyBindings.binded) revert Errors.KeyBinded();

        /// Checks: Ensure that the asset exists in the vault.
        if (asset.class == VaultSingle.SingleClass.NONE) revert Errors.NoAssetLocked();

        /// Checks: Ensure a valid amount of keys has been specified.
        if (amount == 0) revert Errors.InvalidKeyAmount();

        /// Mint the desired amount of keys to the owner.
        uint256 keyId = keys.createKeys(amount, msg.sender);

        /// Update the vaults associated key-bindings settings.
        keyBindings = Keys.Bindings({ binded: true, keyId: keyId, amount: amount });

        /// Emit key creation event.
        emit ISegMintVaultSingle.KeysCreated({ vault: address(this), keyId: keyId, amount: amount });
    }

    /**
     * @inheritdoc ISegMintVaultSingle
     */
    function unbindKeys() external override {
        /// Checks: Ensure the vault is key-binded.
        if (!keyBindings.binded) revert Errors.NotKeyBinded();

        /// Cache previous key-bindings settings in memory.
        Keys.Bindings memory _keyBindings = keyBindings;

        /// Checks: Ensure the caller holds the full amount of keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBindings.keyId);
        if (keysHeld != _keyBindings.amount) revert Errors.InsufficientKeys();

        /// Reset state related to key-bindings settings.
        keyBindings = Keys.Bindings({ binded: false, keyId: 0, amount: 0 });

        /// Burn the keys associated with the vault.
        keys.burnKeys(msg.sender, _keyBindings.keyId, _keyBindings.amount);

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
