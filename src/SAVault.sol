// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IDelegateRegistry } from "@delegate-registry/src/IDelegateRegistry.sol";
import { ISAVault } from "./interfaces/ISAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { AssetClass, Asset, VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title SAVault - Single Asset Vault
 * @notice Used to lock and fractionalize a single asset, limited to ERC721 and ERC1155 tokens.
 */

contract SAVault is ISAVault, Initializable {
    /// @dev delegate.xyz V2 Registry
    IDelegateRegistry public constant DELEGATE_V2_REGISTRY = IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);

    Asset private _lockedAsset;

    IKeys public keys;

    /**
     * @inheritdoc ISAVault
     */
    uint256 public boundKeyId;

    constructor() {
        /// Prevent implementation contract from being initialized.
        _disableInitializers();
    }

    /**
     * @inheritdoc ISAVault
     */
    function initialize(Asset calldata _asset, IKeys _keys, uint256 _keyAmount, address _receiver, bool _delegateAsset)
        external
        initializer
    {
        /// Checks: Ensure the asset has a non-zero amount value.
        if (_asset.amount == 0) revert ZeroAssetAmount();

        /// Checks: Ensure the asset being locked is a valid type.
        if (_asset.class == AssetClass.NONE || _asset.class == AssetClass.ERC20) revert InvalidAssetType();

        /// Checks: Ensure that if the asset is an ERC721 token, the amount is 1.
        if (_asset.class == AssetClass.ERC721 && _asset.amount != 1) revert Invalid721Amount();

        if (address(_keys) == address(0) || _receiver == address(0)) revert ZeroAddressInvalid();

        _lockedAsset = _asset;
        keys = _keys;

        /// Create the keys and mint them to the receiver.
        boundKeyId = keys.createKeys({ amount: _keyAmount, receiver: _receiver, vaultType: VaultType.SINGLE });

        /// If the creator of the Vault has chosen to delegate the underlying asset, all rights will be given to the
        /// creator. These rights can be modified at a later point in time by calling `modifyAssetDelegation`.
        if (_delegateAsset) {
            bytes32 delegationHash = DELEGATE_V2_REGISTRY.delegateAll({ to: _receiver, rights: "", enable: true });
            emit DelegationPerformed(delegationHash);
        }
    }

    /**
     * @inheritdoc ISAVault
     */
    function unlockAsset(address receiver) external {
        /// Checks: Ensure `receiver` is not the zero address to prevent excessive gas consumption.
        if (receiver == address(0)) revert ZeroAddressInvalid();

        /// Copy `Asset` struct into memory.
        Asset memory asset = _lockedAsset;

        /// Checks: Ensure that the locked asset has not already been unlocked.
        if (asset.class == AssetClass.NONE) revert NoAssetLocked();

        /// Clear the locked asset.
        _lockedAsset = Asset({ class: AssetClass.NONE, token: address(0), identifier: 0, amount: 0 });

        /// Burn the keys associated with the vault, this will revert if the caller
        /// doesn't hold the full supply of keys.
        uint256 keySupply = keys.getKeyConfig(boundKeyId).supply;
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
    function modifyAssetDelegation(bytes[] calldata delegationPayloads) external {
        /// Checks: Ensure the delegation payloads array has a valid length.
        if (delegationPayloads.length == 0) revert ZeroLengthArray();

        /// Checks: Ensure that the underlying asset is still locked.
        if (_lockedAsset.class == AssetClass.NONE) revert NoAssetLocked();

        /// Checks: Ensure the caller is the creator of the Vault.
        if (keys.getKeyConfig(boundKeyId).creator != msg.sender) revert CallerNotVaultCreator();

        /// Call the delegation V2 registry with the encoded payloads.
        bytes[] memory results = DELEGATE_V2_REGISTRY.multicall(delegationPayloads);
        
        /// Iterate over the returned results and emit the respective delegation hashes.
        for (uint256 i = 0; i < results.length;) {
            emit DelegationPerformed(abi.decode(results[i], (bytes32)));
            unchecked { ++i; }
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
