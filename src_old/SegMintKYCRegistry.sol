// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { ISegMintSignerModule } from "./interfaces/ISegMintSignerModule.sol";
import { Errors } from "./libraries/Errors.sol";
import { KYCRegistry } from "./types/DataTypes.sol";

/**
 * @title SegMintKYCRegistry
 * @notice Reports the access type that an address has within the SegMint ecosystem.
 */

contract SegMintKYCRegistry is ISegMintKYCRegistry, OwnableRoles {
    using ECDSA for bytes32;

    ISegMintSignerModule public signerModule;

    mapping(address account => KYCRegistry.AccessType accessType) private _access;

    constructor(address admin_, ISegMintSignerModule signerModule_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);
        signerModule = signerModule_;
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function initAccessType(bytes calldata signature, KYCRegistry.AccessType newAccessType) external override {
        /// Checks: Ensure the access type for `msg.sender` has not previously been defined.
        if (_access[msg.sender] != KYCRegistry.AccessType.BLOCKED) revert Errors.AccessTypeSet();

        /// Checks: Ensure the access type is not `AccessType.BLOCKED` on initialisation.
        if (newAccessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the signature provided has been signed by the registered signer.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, newAccessType, "INIT_ACCESS_TYPE"));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signerModule.getSigner() != recoveredSigner) revert Errors.SignerMismatch();

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
        KYCRegistry.AccessType oldAccessType = _access[account];
        _access[account] = newAccessType;

        emit ISegMintKYCRegistry.AccessTypeModified({
            admin: msg.sender,
            account: account,
            oldAccessType: oldAccessType,
            newAccessType: newAccessType
        });
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function setSignerModule(ISegMintSignerModule newSignerModule) external override onlyRoles(_ROLE_0) {
        ISegMintSignerModule oldSignerModule = signerModule;
        signerModule = newSignerModule;

        emit ISegMintKYCRegistry.SignerModuleUpdated({
            admin: msg.sender,
            oldSignerModule: oldSignerModule,
            newSignerModule: newSignerModule
        });
    }

    /**
     * @inheritdoc ISegMintKYCRegistry
     */
    function getAccessType(address account) external view override returns (KYCRegistry.AccessType) {
        return _access[account];
    }
}
