// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISegMintVault } from "./interfaces/ISegMintVault.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import { Errors } from "./libraries/Errors.sol";
import { Class, Vault, Keys } from "./types/DataTypes.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";

contract SegMintVault is ISegMintVault, Ownable, Initializable {
    using SafeERC20 for IERC20;

    /**
     * @dev Maximum number of movable assets in one transaction.
     */
    uint256 private constant _ASSET_MOVEMENT_LIMIT = 20;

    /**
     * @inheritdoc ISegMintVault
     */
    ISegMintKeys public keys;

    Keys.Bindings public keyBindings;

    /**
     * @inheritdoc ISegMintVault
     */
    function initialize(address owner_, ISegMintKeys keys_) external initializer {
        _initializeOwner(owner_);
        keys = keys_;
    }

    /**
     * @inheritdoc ISegMintVault
     * @dev Off-chain indexer will keep track of assets locked into a vault using
     * the transfer events emitted from each assets token standard.
     * @custom:note If a vault is key-binded, no assets can be locked.
     */
    function lockAssets(Vault.Asset[] calldata assets) external override onlyOwner {
        /// Checks: Ensure a valid amount of assets has been provided.
        if (assets.length == 0) revert Errors.ZeroLengthArray();
        if (assets.length > _ASSET_MOVEMENT_LIMIT) revert Errors.OverMovementLimit();

        /// Checks: Ensure that assets can't be deposited into a key-binded vault.
        if (keyBindings.binded) revert Errors.KeyBinded();

        for (uint256 i = 0; i < assets.length; i++) {
            Vault.Asset memory asset = assets[i];

            /// forgefmt: disable-next-item
            if (asset.class == Class.ERC_20) {
                IERC20(asset.addr).safeTransferFrom({
                    from: msg.sender,
                    to: address(this),
                    value: asset.amount
                });
            } else if (asset.class == Class.ERC_721) {
                IERC721(asset.addr).safeTransferFrom({
                    from: msg.sender,
                    to: address(this),
                    tokenId: asset.tokenId
                });
            } else {
                IERC1155(asset.addr).safeTransferFrom({
                    from: msg.sender,
                    to: address(this),
                    id: asset.tokenId,
                    amount: asset.amount,
                    data: ""
                });
            }
        }
    }

    /**
     * @inheritdoc ISegMintVault
     * @dev Off-chain indexer will keep track of assets unlocked from a vault using
     * the transfer events emitted from each assets token standard.
     */
    function unlockAssets(Vault.Asset[] calldata assets, address receiver) external override {
        /// Checks: Ensure a valid amount of assets has been provided.
        if (assets.length == 0) revert Errors.ZeroLengthArray();
        if (assets.length > _ASSET_MOVEMENT_LIMIT) revert Errors.OverMovementLimit();

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

        for (uint256 i = 0; i < assets.length; i++) {
            Vault.Asset memory asset = assets[i];

            /// forgefmt: disable-next-item
            if (asset.class == Class.ERC_20) {
                IERC20(asset.addr).safeTransfer({
                    to: receiver,
                    value: asset.amount
                });
            } else if (asset.class == Class.ERC_721) {
                IERC721(asset.addr).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    tokenId: asset.tokenId
                });
            } else {
                IERC1155(asset.addr).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    id: asset.tokenId,
                    amount: asset.amount,
                    data: ""
                });
            }
        }
    }

    /**
     * @inheritdoc ISegMintVault
     */
    function unlockEther(uint256 amount, address receiver) external {
        /// Copy key bindings struct into memory to avoid SLOADs.
        Keys.Bindings memory _keyBindings = keyBindings;

        /// If a vault is key-binded, only the holder of all keys can unlock Ether.
        if (_keyBindings.binded) {
            uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, _keyBindings.keyId);
            if (keysHeld != _keyBindings.amount) revert Errors.InsufficientKeys();
        } else {
            /// Reverts with `Unauthorized()` if caller is not the owner.
            _checkOwner();
        }

        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert Errors.TransferFailed();
    }

    /**
     * @inheritdoc ISegMintVault
     * @dev Discuss if there is a key limit.
     */
    function bindKeys(uint256 amount) external onlyOwner {
        /// Checks: Ensure the vault is not already key-binded.
        if (keyBindings.binded) revert Errors.KeyBinded();

        /// Checks: Ensure a valid amount of keys has been specified.
        if (amount == 0) revert Errors.InvalidKeyAmount();

        /// Mint the desired amount of keys to the owner.
        uint256 keyId = keys.createKeys(amount, msg.sender);

        /// Update the vaults associated key-bindings settings.
        keyBindings = Keys.Bindings({ binded: true, keyId: keyId, amount: amount });

        /// Emit key creation event.
        emit ISegMintVault.KeysCreated({ vault: address(this), keyId: keyId, amount: amount });
    }

    /**
     * @inheritdoc ISegMintVault
     */
    function unbindKeys() external {
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
        emit ISegMintVault.KeysBurned({ vault: address(this), keyId: _keyBindings.keyId, amount: _keyBindings.amount });
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
     * Fallback used for Ether receival.
     */
    receive() external payable { }
}
