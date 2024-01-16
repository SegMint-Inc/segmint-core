// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { OwnableRoles } from "@solady/src/auth/OwnableRoles.sol";
import { AccessRoles } from "../access/AccessRoles.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title SignerRegistry
 * @notice Allows the ecosystem signer address to be queried from a single contract.
 */

contract SignerRegistry is ISignerRegistry, OwnableRoles {
    address private _signer;

    constructor(address admin_, address signer_) {
        if (admin_ == address(0) || signer_ == address(0)) revert ZeroAddressInvalid();

        _initializeOwner(msg.sender);
        _grantRoles({ user: admin_, roles: AccessRoles.ADMIN_ROLE });

        _signer = signer_;

        emit ISignerRegistry.SignerUpdated({ admin: msg.sender, oldSigner: address(0), newSigner: signer_ });
    }

    /**
     * @inheritdoc ISignerRegistry
     */
    function setSigner(address newSigner) external onlyRoles(AccessRoles.ADMIN_ROLE) {
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
