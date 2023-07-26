// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ISegMintSignerModule } from "./interfaces/ISegMintSignerModule.sol";

/**
 * @title SegMintSignerModule
 * @notice See documentation for {ISegMintSignerModule}.
 */

contract SegMintSignerModule is ISegMintSignerModule, OwnableRoles {
    address private _signer;

    constructor(address admin_, address signer_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);

        _signer = signer_;

        emit ISegMintSignerModule.SignerUpdated({ admin: msg.sender, oldSigner: address(0), newSigner: signer_ });
    }

    /**
     * @inheritdoc ISegMintSignerModule
     */
    function setSigner(address newSigner) external override onlyRoles(_ROLE_0) {
        address oldSigner = _signer;
        _signer = newSigner;

        emit ISegMintSignerModule.SignerUpdated({ admin: msg.sender, oldSigner: oldSigner, newSigner: newSigner });
    }

    /**
     * @inheritdoc ISegMintSignerModule
     */
    function getSigner() external view override returns (address) {
        return _signer;
    }
}
