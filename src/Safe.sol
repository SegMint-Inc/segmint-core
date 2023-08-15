// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISafe } from "./interfaces/ISafe.sol";
import { SelfAuthorized } from "./SelfAuthorized.sol";
import { SignerManager } from "./managers/SignerManager.sol";

/**
 * @title Safe
 * @notice See documentation for {ISafe}.
 */

contract Safe is ISafe, SelfAuthorized, SignerManager, Initializable {
    using SafeERC20 for IERC20;

    /// Maximum number of movable assets in one transaction.
    uint256 private constant _ASSET_MOVEMENT_LIMIT = 25;

    /// Maximum number of signers a safe can have.
    uint256 private constant _MAX_SIGNERS = 20;

    /// Mapping to keep track of all message hashes that have been approved by ALL REQUIRED owners
    mapping(bytes32 => uint256) public signedMessages;

    // Mapping to keep track of all hashes (message or transaction) that have been approved by ANY owners
    mapping(address signer => mapping(bytes32 dataHash => bool approved)) public approvedHashes;

    uint256 public nonce;

    function initialize(address[] calldata signers_, uint256 quorumValue_) external initializer {
        /// Checks: Ensure a non-zero amount of signers have been provided.
        if (signers_.length == 0) revert ZeroSignerAmount();

        /// Checks: Ensure the maximum number of signers isn't exceeded.
        if (signers_.length > _MAX_SIGNERS) revert OverMaxSigners();

        _initializeSigners({ signers: signers_, quorumValue: quorumValue_ });
    }

    function unlockAssets(SafeAsset[] calldata assets, address receiver) external selfAuthorized {
        /// Checks: Ensure a non-zero amount of assets has been specified.
        if (assets.length == 0) revert ZeroAssetAmount();

        /// Checks: Ensure the number of assets being unlocked doesn't exceed the movement limit.
        if (assets.length > _ASSET_MOVEMENT_LIMIT) revert OverMovementLimit();

        for (uint256 i = 0; i < assets.length; i++) {
            SafeAsset memory asset = assets[i];

            /// forgefmt: disable-next-item
            if (asset.class == SafeAssetClass.ERC20) {
                IERC20(asset.token).safeTransfer({
                    to: receiver,
                    value: asset.amount
                });
            } else if (asset.class == SafeAssetClass.ERC721) {
                IERC721(asset.token).safeTransferFrom({
                    from: address(this),
                    to: receiver,
                    tokenId: asset.identifier
                });
            } else if (asset.class == SafeAssetClass.ERC1155) {
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
     * Function used to execute a proposal. Proposals are actions that can only be performed on the
     * Safe itself. For this reason, all proposals are executed through a `delegatecall`.
     * @param data Proposal calldata to be executed.
     * @param signatures Ordered signatures from each signer.
     */
    function executeProposal(bytes calldata data, bytes calldata signatures) external { }

    /**
     * Function used to approve a proposal hash.
     */
    function approveProposalHash(bytes32 proposalHash) external {
        /// Checks: Ensure the caller is an approved signer.
        if (_approvedSigners[msg.sender] == address(0)) revert CallerNotSigner();

        /// Approve the proposal hash.
        approvedHashes[msg.sender][proposalHash] = true;
    }

    function unlockNativeToken(uint256 amount, address receiver) external selfAuthorized {
        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert NativeTokenUnlockFailed();
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
     * Fallback used for Ether receival.
     */
    receive() external payable { }
}
