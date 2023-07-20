// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { Errors } from "./libraries/Errors.sol";
import { KYCRegistry } from "./types/DataTypes.sol";

/**
 * @title SegMintKYCRegistry
 * @notice Reports the access type that an address has within the SegMint ecosystem.
 */

contract SegMintKYCRegistry is ISegMintKYCRegistry, OwnableRoles {
    using ECDSA for bytes32;

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    address public override signer;

    mapping(address account => KYCRegistry.AccessType accessType) private _access;

    constructor(address admin_, address signer_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);
        signer = signer_;
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function initAccessType(bytes calldata signature, KYCRegistry.AccessType newAccessType) external override {
        /// Checks: Ensure the access type for `msg.sender` has not previously been defined.
        if (_access[msg.sender] != KYCRegistry.AccessType.BLOCKED) revert Errors.AccessTypeSet();

        /// Checks: Ensure the access type is not `AccessType.BLOCKED` on initialisation.
        if (newAccessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the signature provided has been signed by `_signer`.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, newAccessType));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signer != recoveredSigner) revert Errors.SignerMismatch();

        _access[msg.sender] = newAccessType;

        emit ISegMintKYCRegistry.AccessTypeSet({ account: msg.sender, accessType: newAccessType });
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function modifyAccessType(address account, KYCRegistry.AccessType newAccessType)
        external
        override
        onlyRoles(_ROLE_0)
    {
        _access[account] = newAccessType;

        emit ISegMintKYCRegistry.AccessTypeModified({ admin: msg.sender, account: account, accessType: newAccessType });
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function setSigner(address newSigner) external override onlyRoles(_ROLE_0) {
        address oldSigner = signer;
        signer = newSigner;

        emit ISegMintKYCRegistry.SignerUpdated({ admin: msg.sender, oldSigner: oldSigner, newSigner: newSigner });
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function getAccessType(address account) external view override returns (KYCRegistry.AccessType) {
        return _access[account];
    }
}
