// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IKYCRegistry } from "../interfaces/IKYCRegistry.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title KYCRegistry
 * @notice See documentation for {IKYCRegistry}.
 */

/// TODO: Rename KYCRegistry to AccessRegistry. Wait for confirmation before doing this.

contract KYCRegistry is IKYCRegistry, OwnableRoles {
    using ECDSA for bytes32;

    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    /// Interface for signer registry.
    ISignerRegistry public signerRegistry;

    mapping(address account => AccessType accessType) public accessType;

    constructor(address admin_, ISignerRegistry signerRegistry_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

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

        bytes32 digest = keccak256(abi.encodePacked(msg.sender, deadline, newAccessType));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);

        /// Checks: Ensure the signature provided has been signed by the registered signer.
        if (signerRegistry.getSigner() != recoveredSigner) revert ISignerRegistry.SignerMismatch();

        accessType[msg.sender] = newAccessType;

        emit AccessTypeSet({ account: msg.sender, accessType: newAccessType, signature: signature });
    }

    /**
     * @inheritdoc IKYCRegistry
     */
    function modifyAccessType(address account, AccessType newAccessType) external onlyRoles(ADMIN_ROLE) {
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
    function setSignerRegistry(ISignerRegistry newSignerRegistry) external onlyRoles(ADMIN_ROLE) {
        signerRegistry = newSignerRegistry;
    }
}
