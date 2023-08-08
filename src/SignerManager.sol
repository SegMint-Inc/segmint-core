// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Errors } from "./libraries/Errors.sol";
import { SelfAuthorized } from "./SelfAuthorized.sol";

/**
 * @title SignerManager
 * @custom:note Inspired from Gnosis Safe's `OwnerManager` with signer expiration.
 * https://github.com/safe-global/safe-contracts/blob/main/contracts/base/OwnerManager.sol
 */

abstract contract SignerManager is SelfAuthorized {
    address internal constant _SENTINEL_VALUE = address(0x01);

    /**
     * @dev Linked list of approved signers.
     */
    mapping(address prevSigner => address nextSigner) internal _approvedSigners;

    /**
     * @dev Expiry time associated with each approved signer.
     */
    mapping(address signer => uint256 expiryTime) internal _expiryTimes;

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

            /// Default each of the initial signers to the maximum expiry time.
            _expiryTimes[currentSigner] = type(uint96).max;
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
    function _removeSigner(address ptrSigner, address signer, uint256 quorumValue) internal {
        if (quorumValue > _signerCount - 1) revert Errors.RemovalBreaksQuorum();
        if (signer == address(0) || signer == _SENTINEL_VALUE) revert Errors.InvalidSigner();
        if (_approvedSigners[ptrSigner] != signer) revert Errors.InvalidPointer();

        _approvedSigners[ptrSigner] = _approvedSigners[signer];
        _approvedSigners[signer] = address(0);
        _signerCount--;

        _expiryTimes[signer] = 0;

        if (_quorumValue != quorumValue) {
            updateQuorum(quorumValue);
        }
    }

    /**
     * Function used to view if a signer has expired.
     * @param signer The signer address to check the expiry status of.
     */
    function _isExpired(address signer) internal view returns (bool) {
        return block.timestamp > _expiryTimes[signer];
    }

    /**
     * Function used to add a signer and update the quorum value.
     * @param newSigner Address of the new signer to be added.
     * @param expiryTime Expiration time of the new signer.
     * @param quorumValue Number of signer approvals to reach quorum on a proposal.
     */
    function addSigner(address newSigner, uint96 expiryTime, uint256 quorumValue) public selfAuthorized {
        /// forgefmt: disable-next-item
        /// Checks: Ensure `signer` is a valid address.
        if (
            newSigner == address(0) ||      // not zero address.
            newSigner == _SENTINEL_VALUE || // not sentinel value.
            newSigner == address(this)      // not self.
        ) revert Errors.InvalidSigner();

        /// Checks: Ensure `signer` is not already an authorized signer.
        if (_approvedSigners[newSigner] != address(0)) revert Errors.DuplicateSigner();

        /// Checks: Ensure a valid expiry time has been provided.
        if (block.timestamp >= expiryTime) revert Errors.InvalidExpiryTime();

        _approvedSigners[newSigner] = _approvedSigners[_SENTINEL_VALUE];
        _approvedSigners[_SENTINEL_VALUE] = newSigner;

        _expiryTimes[newSigner] = expiryTime;

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
     * @param expiryTime Expiration time of the new signer.
     */
    function swapSigner(address ptrSigner, address oldSigner, address newSigner, uint96 expiryTime)
        public
        selfAuthorized
    {
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

        /// Checks: Ensure a valid expiry time has been provided.
        if (block.timestamp >= expiryTime) revert Errors.InvalidExpiryTime();

        _approvedSigners[newSigner] = _approvedSigners[oldSigner];
        _approvedSigners[ptrSigner] = newSigner;
        _approvedSigners[oldSigner] = address(0);

        _expiryTimes[newSigner] = expiryTime;
    }

    function removeSigner(address ptrSigner, address signer, uint256 quorumValue) public selfAuthorized {
        _removeSigner(ptrSigner, signer, quorumValue);
    }

    /**
     * Function used to set the expiry time associated with a signer.
     * @param signer Address of the signer whose expiry time needs to be modified.
     * @param expiryTime New expiration time of the signer.
     */
    function modifySignerExpiry(address signer, uint96 expiryTime) public selfAuthorized {
        /// Checks: Ensure the signer being modified is valid.
        if (_approvedSigners[signer] == address(0) || signer == _SENTINEL_VALUE) revert Errors.SignerNotApproved();

        /// Checks: Ensure a valid expiry time has been provided.
        if (block.timestamp >= expiryTime) revert Errors.InvalidExpiryTime();

        _expiryTimes[signer] = expiryTime;
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
     * Function used to view if `account` is an approved signer.
     */
    function isSigner(address account) public view returns (bool) {
        return account != _SENTINEL_VALUE && _approvedSigners[account] != address(0);
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
     * Function used to view the current quorum value.
     */
    function quorum() public view returns (uint256) {
        return _quorumValue;
    }

    function isExpired(address signer) public view returns (bool) {
        return _isExpired(signer);
    }

    /**
     * Function used to view when a signer expires.
     * @param signer The signer address to check the expiration of.
     */
    function getExpiry(address signer) public view returns (uint256) {
        return _expiryTimes[signer];
    }
}
