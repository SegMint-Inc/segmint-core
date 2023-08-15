// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISignerManager } from "../interfaces/ISignerManager.sol";
import { SelfAuthorized } from "../SelfAuthorized.sol";

/**
 * @title SignerManager
 * @custom:note Inspired from Gnosis Safe's `OwnerManager`.
 * https://github.com/safe-global/safe-contracts/blob/main/contracts/base/OwnerManager.sol
 */

abstract contract SignerManager is ISignerManager, SelfAuthorized {
    address internal constant _SENTINEL_VALUE = address(0x01);

    /// Linked list of approved signers.
    mapping(address prevSigner => address nextSigner) internal _approvedSigners;

    /// Number of signers associated with the Safe.
    uint256 internal _signerCount;

    /// Proposal quorum value.
    uint256 internal _quorumValue;

    /**
     * Function used to initialize the signers associated with a safe.
     * @param signers List of intended signers to initialize the safe with.
     * @param quorumValue Number of approvals required to reach quorum.
     */
    function _initializeSigners(address[] calldata signers, uint256 quorumValue) internal {
        address currentSigner = _SENTINEL_VALUE;

        for (uint256 i = 0; i < signers.length; i++) {
            address signer = signers[i];

            /// forgefmt: disable-next-item
            /// Checks: Ensure `signer` is a valid address.
            if (
                signer == address(0) ||         // not zero address.
                signer == _SENTINEL_VALUE ||    // not sentinel value.
                signer == address(this) ||      // not self.
                currentSigner == signer         // not concurrent index duplicate.
            ) revert InvalidSigner();

            /// Checks: Ensure `signer` is not already an authorized signer.
            if (_approvedSigners[currentSigner] != address(0)) revert DuplicateSigner();

            _approvedSigners[currentSigner] = signer;
            currentSigner = signer;
        }

        _approvedSigners[currentSigner] = _SENTINEL_VALUE;
        _signerCount = signers.length;
        _quorumValue = quorumValue;
    }

    /**
     * @inheritdoc ISignerManager
     */
    function removeSigner(address ptrSigner, address signer, uint256 quorumValue) public selfAuthorized {
        if (quorumValue > _signerCount - 1) revert RemovalBreaksQuorum();
        if (signer == address(0) || signer == _SENTINEL_VALUE) revert InvalidSigner();
        if (_approvedSigners[ptrSigner] != signer) revert InvalidPointer();

        _approvedSigners[ptrSigner] = _approvedSigners[signer];
        _approvedSigners[signer] = address(0);
        _signerCount--;

        if (_quorumValue != quorumValue) {
            updateQuorum(quorumValue);
        }
    }

    /**
     * @inheritdoc ISignerManager
     */
    function addSigner(address newSigner, uint256 quorumValue) public selfAuthorized {
        /// forgefmt: disable-next-item
        /// Checks: Ensure `signer` is a valid address.
        if (
            newSigner == address(0) ||      // not zero address.
            newSigner == _SENTINEL_VALUE || // not sentinel value.
            newSigner == address(this)      // not self.
        ) revert InvalidSigner();

        /// Checks: Ensure `signer` is not already an authorized signer.
        if (_approvedSigners[newSigner] != address(0)) revert DuplicateSigner();

        _approvedSigners[newSigner] = _approvedSigners[_SENTINEL_VALUE];
        _approvedSigners[_SENTINEL_VALUE] = newSigner;

        _signerCount++;

        if (_quorumValue != quorumValue) {
            updateQuorum(quorumValue);
        }
    }

    /**
     * @inheritdoc ISignerManager
     */
    function swapSigner(address ptrSigner, address oldSigner, address newSigner) public selfAuthorized {
        /// forgefmt: disable-next-item
        // Owner address cannot be null, the sentinel or the Safe itself.
        if (
            newSigner == address(0) ||      // not zero address.
            newSigner == _SENTINEL_VALUE || // not sentinel value.
            newSigner == address(this)      // not self.
        ) revert InvalidSigner();

        // No duplicate owners allowed.
        if (_approvedSigners[newSigner] != address(0)) revert DuplicateSigner();

        // Validate oldOwner address and check that it corresponds to owner index.
        // TODO: Rename this error.
        if (oldSigner == address(0) || oldSigner == _SENTINEL_VALUE) revert InvalidSigner();
        if (_approvedSigners[ptrSigner] != oldSigner) revert PointerMismatch();

        _approvedSigners[newSigner] = _approvedSigners[oldSigner];
        _approvedSigners[ptrSigner] = newSigner;
        _approvedSigners[oldSigner] = address(0);
    }

    /**
     * @inheritdoc ISignerManager
     */
    function updateQuorum(uint256 quorumValue) public selfAuthorized {
        if (quorumValue == 0 || quorumValue > _signerCount) revert InvalidQuorumValue();
        _quorumValue = quorumValue;
    }

    /**
     * @inheritdoc ISignerManager
     */
    function getSigners() public view returns (address[] memory) {
        address[] memory _signers = new address[](_signerCount);

        uint256 idx = 0;
        address currentSigner = _approvedSigners[_SENTINEL_VALUE];

        while (currentSigner != _SENTINEL_VALUE) {
            _signers[idx] = currentSigner;
            currentSigner = _approvedSigners[currentSigner];
            idx++;
        }

        return _signers;
    }

    /**
     * @inheritdoc ISignerManager
     */
    function isSigner(address account) public view returns (bool) {
        return account != _SENTINEL_VALUE && _approvedSigners[account] != address(0);
    }

    /**
     * @inheritdoc ISignerManager
     */
    function quorum() public view returns (uint256) {
        return _quorumValue;
    }
}
