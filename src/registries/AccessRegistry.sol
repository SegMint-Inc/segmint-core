// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { OwnableRoles } from "@solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "@solady/src/utils/ECDSA.sol";
import { EIP712 } from "@solady/src/utils/EIP712.sol";
import { IAccessRegistry } from "../interfaces/IAccessRegistry.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title AccessRegistry
 * @notice Manages the access types associated with an EOA.
 */

contract AccessRegistry is IAccessRegistry, OwnableRoles, EIP712 {
    using ECDSA for bytes32;

    /// `AccessParams(address user,uint256 deadline,uint256 nonce,uint8 accessType)`
    bytes32 private constant _ACCESS_TYPEHASH = 0x99eb3c41b67624484b17b738fcdc21b883ecec4c0c7a35257d05bd82c51b6b37;

    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    /// Interface for signer registry.
    ISignerRegistry public signerRegistry;

    mapping(address account => AccessType accessType) public accessType;
    mapping(address account => uint256 nonce) public accountNonce;

    constructor(address admin_, ISignerRegistry signerRegistry_) {
        if (admin_ == address(0) || address(signerRegistry_) == address(0)) revert ZeroAddressInvalid();

        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        signerRegistry = signerRegistry_;
    }

    /**
     * @inheritdoc IAccessRegistry
     */
    function initAccessType(AccessParams calldata accessParams, bytes calldata signature) external {
        /// Checks: Ensure the deadline to use the signature hasn't passed.
        if (block.timestamp > accessParams.deadline) revert DeadlinePassed();

        /// Checks: Ensure the access type for `msg.sender` has not previously been defined.
        if (accessType[msg.sender] != AccessType.BLOCKED) revert AccessTypeDefined();

        /// Checks: Ensure `msg.sender` is `accessParams.user`.
        if (msg.sender != accessParams.user) revert UserAddressMismatch();

        /// Checks: Ensure the access type is not `AccessType.BLOCKED` on initialisation.
        if (accessParams.accessType == AccessType.BLOCKED) revert InvalidAccessType();

        /// Checks: Ensure the provided nonce hasn't already been used, post increment after check.
        if (accountNonce[msg.sender]++ != accessParams.nonce) revert NonceUsed();

        address recoveredSigner = _hashAccessParams(accessParams).recover(signature);

        /// Checks: Ensure the signature provided has been signed by the registered signer.
        if (signerRegistry.getSigner() != recoveredSigner) revert ISignerRegistry.SignerMismatch();

        accessType[msg.sender] = accessParams.accessType;

        emit AccessTypeSet({ account: msg.sender, accessType: accessParams.accessType, signature: signature });
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
        if (address(newSignerRegistry) == address(0)) revert ZeroAddressInvalid();

        ISignerRegistry oldSignerRegistry = signerRegistry;
        signerRegistry = newSignerRegistry;

        emit SignerRegistryUpdated({ oldSignerRegistry: oldSignerRegistry, newSignerRegistry: newSignerRegistry });
    }

    /**
     * @inheritdoc IAccessRegistry
     */
    function hashAccessParams(AccessParams calldata accessParams) external view returns (bytes32) {
        return _hashAccessParams(accessParams);
    }

    function _hashAccessParams(AccessParams calldata accessParams) internal view returns (bytes32) {
        /// forgefmt: disable-next-item
        return _hashTypedData(keccak256(abi.encode(
            _ACCESS_TYPEHASH,
            accessParams.user,
            accessParams.deadline,
            accessParams.nonce,
            accessParams.accessType
        )));
    }

    /**
     * Overriden as required in Solady EIP712 documentation.
     */
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "Access Registry";
        version = "1.0";
    }
}
