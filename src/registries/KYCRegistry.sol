// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IKYCRegistry } from "../interfaces/IKYCRegistry.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title KYCRegistry
 * @notice See documentation for {IKYCRegistry}.
 */

contract KYCRegistry is IKYCRegistry, OwnableRoles {
    using ECDSA for bytes32;

    /// @dev keccak256("_ADMIN_ROLE")
    uint256 private constant _ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;

    /// Interface for signer registry.
    ISignerRegistry public signerRegistry;

    mapping(address account => AccessType accessType) public accessType;

    constructor(address admin_, ISignerRegistry signerRegistry_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ADMIN_ROLE);

        signerRegistry = signerRegistry_;
    }

    /**
     * @inheritdoc IKYCRegistry
     */
    function initAccessType(bytes calldata signature, uint256 deadline, AccessType newAccessType) external {
        /// Checks: Ensure the deadline to use the signature hasn't passed.
        if (block.timestamp > deadline) revert DeadlinePassed();

        /// Checks: Ensure the access type for `msg.sender` has not previously been defined.
        if (accessType[msg.sender] != AccessType.BLOCKED) revert AccessTypeDefined();

        /// Checks: Ensure the access type is not `AccessType.BLOCKED` on initialisation.
        if (newAccessType == AccessType.BLOCKED) revert InvalidAccessType();

        bytes32 digest = keccak256(abi.encodePacked(msg.sender, newAccessType));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);

        /// Checks: Ensure the signature provided has been signed by the registered signer.
        if (signerRegistry.getSigner() != recoveredSigner) revert ISignerRegistry.SignerMismatch();

        accessType[msg.sender] = newAccessType;

        emit AccessTypeSet({ account: msg.sender, accessType: newAccessType });
    }

    /**
     * @inheritdoc IKYCRegistry
     */
    function modifyAccessType(address account, AccessType newAccessType) external onlyRoles(_ADMIN_ROLE) {
        AccessType oldAccessType = accessType[account];
        accessType[account] = newAccessType;

        emit AccessTypeModified({
            admin: msg.sender,
            account: account,
            oldAccessType: oldAccessType,
            newAccessType: newAccessType
        });
    }

    /**
     * @inheritdoc IKYCRegistry
     */
    function setSignerModule(ISignerRegistry newSignerModule) external onlyRoles(_ADMIN_ROLE) {
        signerRegistry = newSignerModule;
    }
}
