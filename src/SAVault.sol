// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISAVault } from "./interfaces/ISAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";

/**
 * @title SAVault - Single Asset Vault
 * @notice See documentation for {ISAVault}.
 */

contract SAVault is ISAVault, Initializable {
    /// Interface of Keys contract.
    IKeys public keys;

    /// The locked asset. If an asset has been unlocked, all values should return 0.
    SAVAsset public lockedAsset;

    /// Associated key bindings.
    KeyBinds public keyBinds;

    /**
     * @inheritdoc ISAVault
     */
    /// forgefmt: disable-next-item
    function initialize(
        SAVAsset calldata asset_,
        IKeys keys_,
        uint256 keyAmount_,
        address receiver_
    ) external initializer {
        /// Checks: Ensure the asset being locked is not a key.
        if (asset_.token == address(keys)) revert CannotLockKeys();

        /// Checks: Ensure the asset being locked has a valid type.
        if (asset_.class == SAVAssetClass.NONE) revert NoneAssetType();

        /// Checks: Ensure the asset has a non-zero amount value.
        if (asset_.amount == 0) revert ZeroAmountValue();

        /// Checks: Ensure that if the asset is an ERC721 token, the amount is 1.
        if (asset_.class == SAVAssetClass.ERC721 && asset_.amount != 1) revert Invalid721Amount();

        lockedAsset = asset_;
        keys = keys_;

        uint256 keyId = keys.createKeys({ amount: keyAmount_, receiver: receiver_ });
        keyBinds = KeyBinds({
            keyId: keyId,
            amount: keyAmount_
        });
    }

    /**
     * Function used to unlock an lockedAsset from a vault using keys.
     * @param receiver Receiver of the unlocked lockedAsset.
     */
    function unlockAsset(address receiver) external {
        /// Copy `SAVAsset` struct into memory.
        SAVAsset memory _lockedAsset = lockedAsset;

        /// Checks: Ensure that the locked asset has not already been unlocked.
        if (_lockedAsset.class == SAVAssetClass.NONE) revert NoAssetLocked();

        /// Copy `KeyBinds` struct into memory.
        KeyBinds memory _keyBinds = keyBinds;

        /// Checks: Ensure the caller holds all the keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBinds.keyId);
        if (keysHeld != _keyBinds.amount) revert InsufficientKeys();

        /// Clear the locked asset.
        lockedAsset = SAVAsset({ class: SAVAssetClass.NONE, token: address(0), identifier: 0, amount: 0 });

        /// Clear the associated key bindings.
        keyBinds = KeyBinds({ keyId: 0, amount: 0 });

        /// Burn the keys associated with the vault.
        keys.burnKeys(msg.sender, _keyBinds.keyId, _keyBinds.amount);

        /// Transfer the locked asset to the receiver.
        /// forgefmt: disable-next-item
        if (_lockedAsset.class == SAVAssetClass.ERC721) {
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
