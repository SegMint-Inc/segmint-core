// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { UpgradeHandler } from "../handlers/UpgradeHandler.sol";
import { ISafeFactory } from "../interfaces/ISafeFactory.sol";
import { ISafe } from "../interfaces/ISafe.sol";

/**
 * @title SafeFactory
 * @notice See documentation for {ISafeFactory}.
 */

contract SafeFactory is ISafeFactory, OwnableRoles, UpgradeHandler, Initializable {
    using LibClone for address;
    using ECDSA for bytes32;

    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    address public safe;

    mapping(address account => uint256 nonce) private _safeNonce;

    function initialize(address _admin, address _safe) external initializer {
        _initializeOwner(msg.sender);
        _grantRoles(_admin, ADMIN_ROLE);

        safe = _safe;
    }

    function createSafe(address[] calldata signers, uint256 quorum, bytes calldata signature) external {
        /// Cache current nonce and increment.
        uint256 currentNonce = _safeNonce[msg.sender]++;

        // bytes32 digest = keccak256(abi.encodePacked(msg.sender, block.chainid, currentNonce, "SAFE"));
        // address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);

        /// Checks: Ensure that a valid quorum value has been provided.
        // if (quorum == 0 || quorum > signers.length) revert Errors.InvalidQuorumValue();

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce));

        /// Sanity check to confirm the predicted address matches the actual addresses.
        /// This is done prior to any further storage updates. If this statement ever
        /// fails, chaos ensues.
        address predictedSafe = safe.predictDeterministicAddress(salt, address(this));
        address newSafe = safe.cloneDeterministic(salt);
        if (predictedSafe != newSafe) revert AddressMismatch();

        /// Initialize the newly created clone.
        ISafe(newSafe).initialize(signers, quorum);

        emit ISafeFactory.SafeCreated({ user: msg.sender, safe: newSafe });
    }

    function getSafes(address account) external view returns (address[] memory deployments) {
        uint256 safeNonce = _safeNonce[account];

        for (uint256 i = 0; i < safeNonce; i++) {
            bytes32 salt = keccak256(abi.encodePacked(account, i));
            deployments[i] = safe.predictDeterministicAddress(salt, address(this));
        }

        return deployments;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UPGRADE FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @inheritdoc ISafeFactory
     */
    function proposeUpgrade(address newImplementation) external onlyRoles(ADMIN_ROLE) {
        _proposeUpgrade(newImplementation);
    }

    /**
     * @inheritdoc ISafeFactory
     */
    function cancelUpgrade() external onlyRoles(ADMIN_ROLE) {
        _cancelUpgrade();
    }

    /**
     * @inheritdoc ISafeFactory
     */
    function executeUpgrade(bytes memory payload) external onlyRoles(ADMIN_ROLE) {
        _executeUpgrade(payload);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      VERSION CONTROL                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function nameAndVersion() external pure virtual returns (string memory name, string memory version) {
        name = "Safe Factory";
        version = "1.0";
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Overriden to ensure that only callers with the correct role can upgrade the implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(ADMIN_ROLE) { }
}
