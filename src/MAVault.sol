// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IMAVault } from "./interfaces/IMAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { AssetClass, Asset, VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title MAVault - Multi Asset Vault
 * @notice See documentation for {IMAVault}.
 */

contract MAVault is IMAVault, Ownable, Initializable {
    using SafeERC20 for IERC20;

    /// Interface of Keys contract.
    IKeys public keys;

    /**
     * @inheritdoc IMAVault
     */
    uint256 public boundKeyId;

    /// Block that the last asset withdraw has occured.
    uint256 public lastWithdrawBlock;

    /**
     * Modifier used to ensure the caller is either the owner of the vault if no keys
     * are currently binded, or the holder of all keys. This logic has been moved
     * to an internal function to reduce bytecode size.
     */
    modifier ownerOrKeyHolder() {
        _ownerOrKeyHolder();
        _;
    }

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
    function unlockAssets(Asset[] calldata assets, address receiver) external ownerOrKeyHolder {
        /// Checks: Ensure a non-zero amount of assets has been specified.
        if (assets.length == 0) revert ZeroAssetAmount();

        /// Update the last asset withdraw block.
        lastWithdrawBlock = block.number;

        for (uint256 i = 0; i < assets.length; i++) {
            Asset calldata asset = assets[i];

            /// Checks: Ensure a valid asset type has been provided.
            if (asset.class == AssetClass.NONE) revert NoneAssetType();

            /// forgefmt: disable-next-item
            if (asset.class == AssetClass.ERC20) {
                IERC20(asset.token).safeTransfer({
                    to: receiver,
                    value: asset.amount
                });
            } else if (asset.class == AssetClass.ERC721) {
                IERC721(asset.token).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    tokenId: asset.identifier
                });
            } else {
                IERC1155(asset.token).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    id: asset.identifier,
                    amount: asset.amount,
                    data: ""
                });
            }
        }
    }

    /**
     * @inheritdoc IMAVault
     */
    function unlockNativeToken(uint256 amount, address receiver) external ownerOrKeyHolder {
        /// Update the last asset withdraw block.
        lastWithdrawBlock = block.number;

        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert NativeTokenUnlockFailed();
    }

    /**
     * @inheritdoc IMAVault
     */
    function bindKeys(uint256 keyAmount) external onlyOwner {
        /// Checks: Ensure the vault is not already key binded.
        if (boundKeyId != 0) revert KeysAlreadyBinded();

        /// Mint the desired amount of keys to the owner.
        boundKeyId = keys.createKeys({ amount: keyAmount, receiver: msg.sender, vaultType: VaultType.MULTI });
    }

    /**
     * @inheritdoc IMAVault
     */
    function unbindKeys() external {
        /// Checks: Ensure the vault has keys binded.
        if (boundKeyId == 0) revert NoKeysBinded();

        /// Get the total number of keys in circulation.
        uint256 keySupply = keys.getKeyConfig(boundKeyId).supply;

        /// Checks: Ensure the caller holds the full amount of keys.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, boundKeyId);
        if (keysHeld != keySupply) revert InsufficientKeys();

        /// Burn the associated keys.
        keys.burnKeys(msg.sender, boundKeyId, keySupply);

        /// Return the `boundKeyId` value to 0.
        boundKeyId = 0;
    }

    /**
     * @inheritdoc IMAVault
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

    function _ownerOrKeyHolder() internal view {
        if (boundKeyId != 0) {
            /// Get the total number of keys in circulation.
            uint256 keySupply = keys.getKeyConfig(boundKeyId).supply;
            uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, boundKeyId);

            /// Checks: Ensure the caller holds the correct amount of keys.
            if (keysHeld != keySupply) revert InsufficientKeys();
        } else {
            /// Reverts with `Unauthorized()` if caller is not the owner.
            _checkOwner();
        }
    }

    /**
     * Used for native token receival.
     */
    receive() external payable { }
}
