// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "@solady/src/auth/OwnableRoles.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title SignerRegistry
 * @notice Allows the ecosystem signer address to be queried from a single contract.
 */

contract SignerRegistry is ISignerRegistry, OwnableRoles {
    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;
    address private _signer;

    constructor(address admin_, address signer_) {
        if (admin_ == address(0) || signer_ == address(0)) revert ZeroAddressInvalid();

        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        _signer = signer_;

        emit ISignerRegistry.SignerUpdated({ admin: msg.sender, oldSigner: address(0), newSigner: signer_ });
    }

    /**
     * @inheritdoc ISignerRegistry
     */
    function setSigner(address newSigner) external onlyRoles(ADMIN_ROLE) {
        if (newSigner == address(0)) revert ZeroAddressInvalid();

        address oldSigner = _signer;
        _signer = newSigner;

        emit ISignerRegistry.SignerUpdated({ admin: msg.sender, oldSigner: oldSigner, newSigner: newSigner });
    }

    /**
     * @inheritdoc ISignerRegistry
     */
    function getSigner() external view returns (address) {
        return _signer;
    }
}
