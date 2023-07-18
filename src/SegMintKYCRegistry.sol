// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ISegMintKYCRegistry} from "./interfaces/ISegMintKYCRegistry.sol";
import {OwnableRoles} from "solady/src/auth/OwnableRoles.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title SegMintKYCRegistry
 * @notice Reports the access type that an address has within the SegMint ecosystem.
 */

contract SegMintKYCRegistry is ISegMintKYCRegistry, OwnableRoles {
    using ECDSA for bytes32;

    /// @dev Output of `keccak256("_ADMIN_ROLE")`.
    uint256 private constant _ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;

    address public signer;

    mapping(address account => AccessType accessType) private _access;

    constructor(address admin_, address signer_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ADMIN_ROLE);
        signer = signer_;
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function setAccessType(bytes calldata signature, AccessType newAccessType) external override {
        /// Checks: Ensure the access type for `msg.sender` has not previously been defined.
        if (_access[msg.sender] != AccessType.NONE) revert Errors.AccessTypeSet();

        /// Checks: Ensure the access type is not `AccessType.NONE`.
        if (newAccessType == AccessType.NONE) revert Errors.NoneAccessType();

        /// Checks: Ensure the signature provided has been signed by `_signer`.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, newAccessType));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signer != recoveredSigner) revert Errors.SignerMismatch();

        _access[msg.sender] = newAccessType;

        emit ISegMintKYCRegistry.AccessTypeSet({account: msg.sender, accessType: newAccessType});
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function modifyAccessType(address account, AccessType newAccessType) external override onlyRoles(_ADMIN_ROLE) {
        _access[account] = newAccessType;

        emit ISegMintKYCRegistry.AccessTypeModified({admin: msg.sender, account: account, accessType: newAccessType});
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function setSigner(address newSigner) external override onlyRoles(_ADMIN_ROLE) {
        address oldSigner = signer;
        signer = newSigner;

        emit ISegMintKYCRegistry.SignerUpdated({admin: msg.sender, oldSigner: oldSigner, newSigner: newSigner});
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function getAccessType(address account) external view override returns (AccessType) {
        return _access[account];
    }
}
