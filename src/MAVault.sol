// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { Ownable } from "@solady/src/auth/Ownable.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IDelegateRegistry } from "@delegate-registry/src/IDelegateRegistry.sol";
import { IMAVault } from "./interfaces/IMAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { AssetClass, Asset, VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title MAVault - Multi Asset Vault
 * @notice Used to lock and fractionalize a basket of assets inclusive of ERC20/ERC721/ERC1155 tokens
 * as well as native token.
 */

contract MAVault is IMAVault, Ownable, Initializable {
    using SafeERC20 for IERC20;

    /// @dev delegate.xyz V2 Registry
    IDelegateRegistry public constant DELEGATE_V2_REGISTRY = IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);

    IKeys public keys;

    /**
     * @inheritdoc IMAVault
     */
    uint256 public boundKeyId;

    constructor() {
        /// Prevent implementation contract from being initialized.
        _disableInitializers();
    }

    /**
     * @inheritdoc IMAVault
     */
    function initialize(address owner_, IKeys keys_, uint256 keyAmount_, bool delegateAssets_) external initializer {
        if (owner_ == address(0) || address(keys_) == address(0)) revert ZeroAddressInvalid();

        _initializeOwner(owner_);

        keys = keys_;
        boundKeyId = keys.createKeys({ amount: keyAmount_, receiver: owner_, vaultType: VaultType.MULTI });

        /// If the creator of the Vault has chosen to delegate the underlying asset, all rights will be given to the
        /// creator. These rights can be modified at a later point in time by calling `modifyAssetDelegation`.
        if (delegateAssets_) {
            bytes32 delegationHash = DELEGATE_V2_REGISTRY.delegateAll({ to: owner_, rights: "", enable: true });
            emit DelegationPerformed(delegationHash);
        }
    }

    /**
     * @inheritdoc IMAVault
     * @dev Off-chain indexer will keep track of assets being locked and unlocked from a
     * vault using the transfer events emitted from each assets token standard.
     */
    function unlockAssets(Asset[] calldata assets, address receiver) external onlyOwner {
        /// Checks: Ensure a non-zero amount of assets has been specified.
        if (assets.length == 0) revert ZeroAssetAmount();

        /// Checks: Ensure `receiver` is not zero address to prevent excess gas consumption.
        if (receiver == address(0)) revert ZeroAddressInvalid();

        /// Checks: Ensure the associated keys have been burnt.
        if (boundKeyId != 0) revert KeysBindedToVault();

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
    function unlockNativeToken(address receiver) external onlyOwner {
        /// Checks: Ensure the associated keys have been burnt.
        if (boundKeyId != 0) revert KeysBindedToVault();

        /// Checks: Ensure `receiver` is not zero address to prevent excess gas consumption.
        if (receiver == address(0)) revert ZeroAddressInvalid();

        uint256 amount = address(this).balance;
        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert NativeTokenUnlockFailed();

        emit NativeTokenUnlocked({ receiver: receiver, amount: amount });
    }

    /**
     * @inheritdoc IMAVault
     */
    function claimOwnership() external {
        /// Checks: Ensure a valid key ID is binded to the vault.
        if (boundKeyId == 0) revert NoKeysBindedToVault();

        /// Burn the keys associated with the vault, this will revert if the caller
        /// doesn't hold the full supply of keys.
        uint256 keySupply = keys.getKeyConfig(boundKeyId).supply;
        keys.burnKeys({ holder: msg.sender, keyId: boundKeyId, amount: keySupply });

        /// Reset the bounded key ID.
        boundKeyId = 0;

        /// Transfer ownership to the caller.
        _setOwner(msg.sender);
    }

    /**
     * @inheritdoc IMAVault
     */
    function modifyAssetDelegation(bytes[] calldata delegationPayloads) external onlyOwner {
        /// Checks: Ensure a valid number of delegation rights have been provided.
        if (delegationPayloads.length == 0) revert ZeroLengthArray();

        /// Call the delegation V2 registry with the encoded payloads.
        bytes[] memory results = DELEGATE_V2_REGISTRY.multicall(delegationPayloads);
        
        /// Iterate over the returned results and emit the respective delegation hashes.
        for (uint256 i = 0; i < results.length;) {
            emit DelegationPerformed(abi.decode(results[i], (bytes32)));
            unchecked { ++i; }
        }
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

    /**
     * Used for native token receival.
     */
    receive() external payable { }
}
