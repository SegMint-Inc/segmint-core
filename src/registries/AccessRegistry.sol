// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IAccessRegistry } from "../interfaces/IAccessRegistry.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title AccessRegistry
 * @notice Manages the access types associated with an EOA.
 */

contract AccessRegistry is IAccessRegistry, OwnableRoles {
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
     * @inheritdoc IAccessRegistry
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
     * @inheritdoc IAccessRegistry
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
     * @inheritdoc IAccessRegistry
     */
    function setSignerRegistry(ISignerRegistry newSignerRegistry) external onlyRoles(ADMIN_ROLE) {
        signerRegistry = newSignerRegistry;
    }
}
