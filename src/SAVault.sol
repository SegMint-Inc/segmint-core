// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISAVault } from "./interfaces/ISAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { AssetClass, Asset, VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title SAVault - Single Asset Vault
 * @notice See documentation for {ISAVault}.
 */

contract SAVault is ISAVault, Initializable {
    /// Interface of Keys contract.
    IKeys public keys;

    /// Encapsulates the singular locked asset.
    Asset public lockedAsset;

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
        /// Checks: Ensure the asset being locked is not a key.
        if (_asset.token == address(keys)) revert CannotLockKeys();

        /// Checks: Ensure the asset being locked has a valid type.
        if (_asset.class == AssetClass.NONE || _asset.class == AssetClass.ERC20) revert InvalidAssetType();

        /// Checks: Ensure the asset has a non-zero amount value.
        if (_asset.amount == 0) revert ZeroAmountValue();

        /// Checks: Ensure that if the asset is an ERC721 token, the amount is 1.
        if (_asset.class == AssetClass.ERC721 && _asset.amount != 1) revert Invalid721Amount();

        lockedAsset = _asset;
        keys = _keys;

        /// Create the keys and mint them to the receiver.
        boundKeyId = keys.createKeys({ amount: _keyAmount, receiver: _receiver, vaultType: VaultType.SINGLE });
    }

    /**
     * @inheritdoc ISAVault
     */
    function unlockAsset(address receiver) external {
        /// Copy `Asset` struct into memory.
        Asset memory _asset = lockedAsset;

        /// Checks: Ensure that the locked asset has not already been unlocked.
        if (_asset.class == AssetClass.NONE) revert NoAssetLocked();

        /// Copy `KeyBinds` struct into memory.
        KeyConfig memory keyConfig = keys.getKeyConfig(boundKeyId);

        /// Checks: Ensure the caller holds all the keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, boundKeyId);
        if (keysHeld != keyConfig.supply) revert InsufficientKeys();

        /// Clear the locked asset.
        lockedAsset = Asset({ class: AssetClass.NONE, token: address(0), identifier: 0, amount: 0 });

        /// Burn the keys associated with the vault.
        keys.burnKeys(msg.sender, boundKeyId, keyConfig.supply);

        /// Transfer the locked asset to the receiver.
        /// forgefmt: disable-next-item
        if (_asset.class == AssetClass.ERC721) {
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
    }

    /**
     * @inheritdoc ISAVault
     */
    function getKeyConfig() external view returns (KeyConfig memory) {
        return keys.getKeyConfig(boundKeyId);
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
