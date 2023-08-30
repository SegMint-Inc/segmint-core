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

    /// Key ID associated with this vault.
    uint256 public boundKeyId;

    /**
     * @inheritdoc ISAVault
     */
    function initialize(Asset calldata asset_, IKeys keys_, uint256 keyAmount_, address receiver_)
        external
        initializer
    {
        /// Checks: Ensure the asset being locked is not a key.
        if (asset_.token == address(keys)) revert CannotLockKeys();

        /// Checks: Ensure the asset being locked has a valid type.
        /// @dev Single asset vaults may only contain ERC721 or ERC1155 tokens.
        if (asset_.class == AssetClass.NONE || asset_.class == AssetClass.ERC20) revert InvalidAssetType();

        /// Checks: Ensure the asset has a non-zero amount value.
        if (asset_.amount == 0) revert ZeroAmountValue();

        /// Checks: Ensure that if the asset is an ERC721 token, the amount is 1.
        if (asset_.class == AssetClass.ERC721 && asset_.amount != 1) revert Invalid721Amount();

        lockedAsset = asset_;
        keys = keys_;

        /// Create the keys and mint them to the receiver.
        boundKeyId = keys.createKeys({ amount: keyAmount_, receiver: receiver_, vaultType: VaultType.SINGLE });
    }

    /**
     * Function used to unlock an lockedAsset from a vault using keys.
     * @param receiver Receiver of the unlocked lockedAsset.
     */
    function unlockAsset(address receiver) external {
        /// Copy `Asset` struct into memory.
        Asset memory _lockedAsset = lockedAsset;

        /// Checks: Ensure that the locked asset has not already been unlocked.
        if (_lockedAsset.class == AssetClass.NONE) revert NoAssetLocked();

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
        if (_lockedAsset.class == AssetClass.ERC721) {
            IERC721(_lockedAsset.token).safeTransferFrom({
                from: address(this),
                to: receiver,
                tokenId: _lockedAsset.identifier
            });
        } else {
            IERC1155(_lockedAsset.token).safeTransferFrom({
                from: address(this),
                to: receiver,
                id: _lockedAsset.identifier,
                value: _lockedAsset.amount,
                data: ""
            });
        }
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
