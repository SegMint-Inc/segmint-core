// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IMAVault } from "./interfaces/IMAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";

/**
 * @title MAVault - Multi Asset Vault
 * @notice See documentation for {IMAVault}.
 */

contract MAVault is IMAVault, Ownable, Initializable {
    using SafeERC20 for IERC20;

    /// @dev Maximum number of movable assets in one transaction.
    uint256 private constant _ASSET_MOVEMENT_LIMIT = 25;

    /// Interface of Keys contract.
    IKeys public keys;

    /// Associated key bindings.
    KeyBinds public keyBinds;

    /**
     * @inheritdoc IMAVault
     */
    function initialize(address owner_, IKeys keys_) external initializer {
        _initializeOwner(owner_);
        keys = keys_;
    }

    /**
     * @inheritdoc IMAVault
     * @dev Off-chain indexer will keep track of assets being locked and unlocked from a
     * vault using the transfer events emitted from each assets token standard.
     */
    function unlockAssets(MAVAsset[] calldata assets, address receiver) external {
        /// Checks: Ensure a non-zero amount of assets has been specified.
        if (assets.length == 0) revert ZeroAssetAmount();

        /// Checks: Ensure the number of assets being unlocked doesn't exceed the movement limit.
        if (assets.length > _ASSET_MOVEMENT_LIMIT) revert OverMovementLimit();

        /// Copy key binds into memory.
        KeyBinds memory _keyBinds = keyBinds;

        /// If a vault is key binded, only the holder of all keys can unlock assets.
        if (_keyBinds.keyId != 0) {
            /// Checks: Ensure the caller holds the correct amount of keys.
            uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBinds.keyId);
            if (keysHeld != _keyBinds.amount) revert InsufficientKeys();
        } else {
            /// Reverts with `Unauthorized()` if caller is not the owner.
            _checkOwner();
        }

        for (uint256 i = 0; i < assets.length; i++) {
            MAVAsset calldata asset = assets[i];

            /// forgefmt: disable-next-item
            if (asset.class == MAVAssetClass.ERC20) {
                IERC20(asset.token).safeTransfer({
                    to: receiver,
                    value: asset.amount
                });
            } else if (asset.class == MAVAssetClass.ERC721) {
                IERC721(asset.token).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    tokenId: asset.identifier
                });
            } else if (asset.class == MAVAssetClass.ERC1155) {
                IERC1155(asset.token).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    id: asset.identifier,
                    value: asset.amount,
                    data: ""
                });
            } else {
                /// Checks: Ensure the asset being unlocked has a valid asset class.
                revert NoneAssetType();
            }
        }
    }

    /**
     * @inheritdoc IMAVault
     */
    function unlockNativeToken(uint256 amount, address receiver) external {
        /// Copy key bindings struct into memory to avoid SLOADs.
        KeyBinds memory _keyBinds = keyBinds;

        /// If a vault is key binded, only the holder of all keys can unlock the native token.
        if (_keyBinds.keyId != 0) {
            /// Checks: Ensure the caller holds the correct amount of keys.
            uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBinds.keyId);
            if (keysHeld != _keyBinds.amount) revert InsufficientKeys();
        } else {
            /// Reverts with `Unauthorized()` if caller is not the owner.
            _checkOwner();
        }

        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert NativeTokenUnlockFailed();
    }

    /**
     * @inheritdoc IMAVault
     */
    function bindKeys(uint256 keyAmount) external onlyOwner {
        /// Checks: Ensure the vault is not already key binded.
        if (keyBinds.keyId != 0) revert KeysAlreadyBinded();

        /// Mint the desired amount of keys to the owner.
        uint256 keyId = keys.createKeys({ amount: keyAmount, receiver: msg.sender });

        /// Update the associated key bindings.
        keyBinds = KeyBinds({ keyId: keyId, amount: keyAmount });
    }

    /**
     * @inheritdoc IMAVault
     */
    function unbindKeys() external {
        /// Checks: Ensure the vault has keys binded.
        if (keyBinds.keyId == 0) revert NoKeysBinded();

        /// Cache key bindings in memory.
        KeyBinds memory _keyBinds = keyBinds;

        /// Checks: Ensure the caller holds the full amount of keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBinds.keyId);
        if (keysHeld != _keyBinds.amount) revert InsufficientKeys();

        /// Clear key bindings.
        keyBinds = KeyBinds({ keyId: 0, amount: 0 });

        /// Burn the associated keys.
        keys.burnKeys(msg.sender, _keyBinds.keyId, _keyBinds.amount);
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

    /**
     * See {IERC1155.onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * Used for native token receival.
     */
    receive() external payable { }
}
