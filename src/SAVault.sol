// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISAVault } from "./interfaces/ISAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { AssetClass, Asset, VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title SAVault - Single Asset Vault
 * @notice Locks a single asset upon creation and mints the desired number of keys to the creator. From this
 * point onwards, a future caller must hold all keys to unlock the underlying asset.
 */

contract SAVault is ISAVault, Initializable {
    /// Encapsulates the underlying locked asset.
    Asset private _lockedAsset;

    IKeys public keys;

    /**
     * @inheritdoc ISAVault
     */
    uint256 public boundKeyId;

    /**
     * @inheritdoc ISAVault
     */
    function initialize(Asset calldata _asset, IKeys _keys, uint256 _keyAmount, address _receiver)
        external
        initializer
    {
        /// Checks: Ensure the asset has a non-zero amount value.
        if (_asset.amount == 0) revert ZeroAssetAmount();

        /// Checks: Ensure the asset being locked is a valid type.
        if (_asset.class == AssetClass.NONE || _asset.class == AssetClass.ERC20) revert InvalidAssetType();

        /// Checks: Ensure that if the asset is an ERC721 token, the amount is 1.
        if (_asset.class == AssetClass.ERC721 && _asset.amount != 1) revert Invalid721Amount();

        _lockedAsset = _asset;
        keys = _keys;

        /// Create the keys and mint them to the receiver.
        boundKeyId = keys.createKeys({ amount: _keyAmount, receiver: _receiver, vaultType: VaultType.SINGLE });
    }

    /**
     * @inheritdoc ISAVault
     */
    function unlockAsset(address receiver) external {
        /// Get the current key supply.
        uint256 keySupply = keys.getKeyConfig(boundKeyId).supply;

        /// Checks: Ensure the caller holds all the keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, boundKeyId);
        if (keysHeld != keySupply) revert InsufficientKeys();

        /// Copy `Asset` struct into memory.
        Asset memory asset = _lockedAsset;

        /// Checks: Ensure that the locked asset has not already been unlocked.
        if (asset.class == AssetClass.NONE) revert NoAssetLocked();

        /// Clear the locked asset.
        _lockedAsset = Asset({ class: AssetClass.NONE, token: address(0), identifier: 0, amount: 0 });

        /// Burn the keys associated with the vault.
        keys.burnKeys({ holder: msg.sender, keyId: boundKeyId, amount: keySupply });

        /// Clear the bound key ID.
        boundKeyId = 0;

        /// Transfer the locked asset to the receiver.
        if (asset.class == AssetClass.ERC721) {
            IERC721(asset.token).safeTransferFrom(address(this), receiver, asset.identifier);
        } else {
            IERC1155(asset.token).safeTransferFrom(address(this), receiver, asset.identifier, asset.amount, "");
        }
    }

    /**
     * @inheritdoc ISAVault
     */
    function getKeyConfig() external view returns (KeyConfig memory) {
        return keys.getKeyConfig(boundKeyId);
    }

    /**
     * @inheritdoc ISAVault
     */
    function lockedAsset() external view returns (Asset memory) {
        return _lockedAsset;
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
