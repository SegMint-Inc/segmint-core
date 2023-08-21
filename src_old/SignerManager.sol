// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Errors } from "./libraries/Errors.sol";
import { SelfAuthorized } from "./SelfAuthorized.sol";

/**
 * @title SignerManager
 * @custom:note Inspired from Gnosis Safe's `OwnerManager`.
 * https://github.com/safe-global/safe-contracts/blob/main/contracts/base/OwnerManager.sol
 */

abstract contract SignerManager is SelfAuthorized {
    address internal constant _SENTINEL_VALUE = address(0x01);

    /**
     * @dev Linked list of approved signers.
     */
    mapping(address prevSigner => address nextSigner) internal _approvedSigners;

    /**
     * @dev Number of signers associated with the Safe.
     */
    uint256 internal _signerCount;

    /**
     * @dev Proposal quorum value.
     */
    uint256 internal _quorumValue;

    /**
     * Function used to initialize the signers associated with a Safe and set a quorum value.
     * @param signers Array of initial signer addresses.
     * @param quorumValue Number of signer approvals to reach quorum on a proposal.
     * @dev This function is only called once upon initialization, input sanitisation
     * is passed off to the factory contract that creates Safes.
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
            ) revert Errors.InvalidSigner();

            /// Checks: Ensure `signer` is not already an authorized signer.
            if (_approvedSigners[currentSigner] != address(0)) revert Errors.DuplicateSigner();

            _approvedSigners[currentSigner] = signer;
            currentSigner = signer;
        }

        _approvedSigners[currentSigner] = _SENTINEL_VALUE;
        _signerCount = signers.length;
        _quorumValue = quorumValue;
    }

    /**
     * Function used to remove a signer and update the quorum value.
     * @param ptrSigner Signer address that points to `signer` in the linked list.
     * @param signer Address of the signer to be removed.
     * @param quorumValue Number of signer approvals to reach quorum on a proposal.
     */
    function removeSigner(address ptrSigner, address signer, uint256 quorumValue) public selfAuthorized {
        if (quorumValue > _signerCount - 1) revert Errors.RemovalBreaksQuorum();
        if (signer == address(0) || signer == _SENTINEL_VALUE) revert Errors.InvalidSigner();
        if (_approvedSigners[ptrSigner] != signer) revert Errors.InvalidPointer();

        _approvedSigners[ptrSigner] = _approvedSigners[signer];
        _approvedSigners[signer] = address(0);
        _signerCount--;

        if (_quorumValue != quorumValue) {
            updateQuorum(quorumValue);
        }
    }

    /**
     * Function used to add a signer and update the quorum value.
     * @param newSigner Address of the new signer to be added.
     * @param quorumValue Number of signer approvals to reach quorum on a proposal.
     */
    function addSigner(address newSigner, uint256 quorumValue) public selfAuthorized {
        /// forgefmt: disable-next-item
        /// Checks: Ensure `signer` is a valid address.
        if (
            newSigner == address(0) ||      // not zero address.
            newSigner == _SENTINEL_VALUE || // not sentinel value.
            newSigner == address(this)      // not self.
        ) revert Errors.InvalidSigner();

        /// Checks: Ensure `signer` is not already an authorized signer.
        if (_approvedSigners[newSigner] != address(0)) revert Errors.DuplicateSigner();

        _approvedSigners[newSigner] = _approvedSigners[_SENTINEL_VALUE];
        _approvedSigners[_SENTINEL_VALUE] = newSigner;

        _signerCount++;

        if (_quorumValue != quorumValue) {
            updateQuorum(quorumValue);
        }
    }

    /**
     * Function used to swap `oldSigner` with `newSigner` and update the quorum value.
     * @param ptrSigner Signer address that points to `signer` in the linked list.
     * @param oldSigner Address of the old signer to be removed.
     * @param newSigner Address of the new signer to be added.
     */
    function swapSigner(address ptrSigner, address oldSigner, address newSigner) public selfAuthorized {
        /// forgefmt: disable-next-item
        // Owner address cannot be null, the sentinel or the Safe itself.
        if (
            newSigner == address(0) ||      // not zero address.
            newSigner == _SENTINEL_VALUE || // not sentinel value.
            newSigner == address(this)      // not self.
        ) revert Errors.InvalidSigner();

        // No duplicate owners allowed.
        if (_approvedSigners[newSigner] != address(0)) revert Errors.DuplicateSigner();

        // Validate oldOwner address and check that it corresponds to owner index.
        // TODO: Rename this error.
        if (oldSigner == address(0) || oldSigner == _SENTINEL_VALUE) revert Errors.InvalidSigner();
        if (_approvedSigners[ptrSigner] != oldSigner) revert Errors.PointerMismatch();

        _approvedSigners[newSigner] = _approvedSigners[oldSigner];
        _approvedSigners[ptrSigner] = newSigner;
        _approvedSigners[oldSigner] = address(0);
    }

    /**
     * Function used to update the quorum value.
     * @param quorumValue New number of approvals required to reach quorum on a proposal.
     */
    function updateQuorum(uint256 quorumValue) public selfAuthorized {
        if (quorumValue == 0 || quorumValue > _signerCount) revert Errors.InvalidQuorumValue();
        _quorumValue = quorumValue;
    }

    /**
     * Function used to view all the approved signers of a Safe.
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
     * Function used to view if `account` is an approved signer.
     */
    function isSigner(address account) public view returns (bool) {
        return account != _SENTINEL_VALUE && _approvedSigners[account] != address(0);
    }

    /**
     * Function used to view the current quorum value.
     */
    function quorum() public view returns (uint256) {
        return _quorumValue;
    }
}
