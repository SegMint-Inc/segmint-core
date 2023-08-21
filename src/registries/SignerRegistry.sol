// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title SignerRegistry
 * @notice See documentation for {ISignerRegistry}.
 */

contract SignerRegistry is ISignerRegistry, OwnableRoles {
    /// @dev keccak256("_ADMIN_ROLE")
    uint256 private constant _ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;
    address private _signer;

    constructor(address admin_, address signer_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ADMIN_ROLE);

        _signer = signer_;

        emit ISignerRegistry.SignerUpdated({ admin: msg.sender, oldSigner: address(0), newSigner: signer_ });
    }

    /**
     * @inheritdoc ISignerRegistry
     */
    function setSigner(address newSigner) external onlyRoles(_ADMIN_ROLE) {
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
