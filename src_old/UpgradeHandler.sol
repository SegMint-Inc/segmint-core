// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import { Errors } from "./libraries/Errors.sol";
import { IUpgradeHandler } from "./interfaces/IUpgradeHandler.sol";

/**
 * @title UpgradeHandler
 * @notice This contract is responsible for handling any upgrades that are proposed to the
 * parent contract, it does so with a timelock whereby the duration is defined by `_UPGRADE_TIMELOCK`.
 */

abstract contract UpgradeHandler is IUpgradeHandler, UUPSUpgradeable {
    /// Implementation upgrade proposals cannot be executed for 5 days.
    uint256 private constant _UPGRADE_TIMELOCK = 5 days;

    /// The current upgrade proposal, if one exists.
    IUpgradeHandler.UpgradeProposal public upgradeProposal;

    function _proposeUpgrade(address newImplementation) internal {
        /// Checks: Ensure that a proposal is not currently in progress.
        if (upgradeProposal.deadline != 0) revert Errors.ProposalInProgress();

        uint40 proposalDeadline = uint40(block.timestamp + _UPGRADE_TIMELOCK);

        /// forgefmt: disable-next-item
        upgradeProposal = IUpgradeHandler.UpgradeProposal({
            newImplementation: newImplementation,
            deadline: proposalDeadline
        });

        emit IUpgradeHandler.UpgradeProposed({
            admin: msg.sender,
            implementation: newImplementation,
            deadline: proposalDeadline
        });
    }

    function _cancelUpgrade() internal {
        /// Checks: Ensure there is a proposal to cancel.
        if (upgradeProposal.deadline == 0) revert Errors.NoProposalExists();

        address proposedImplementation = upgradeProposal.newImplementation;
        upgradeProposal = IUpgradeHandler.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        emit IUpgradeHandler.UpgradeCancelled({ admin: msg.sender, implementation: proposedImplementation });
    }

    function _executeUpgrade(bytes memory payload) internal {
        /// Checks: Ensure the proposed implementation is non-zero.
        if (upgradeProposal.newImplementation == address(0)) revert Errors.NoProposalExists();

        /// Checks: Ensure the time lock has expired.
        if (upgradeProposal.deadline > block.timestamp) revert Errors.UpgradeTimeLocked();

        address proposedImplementation = upgradeProposal.newImplementation;

        /// Clear the previous upgrade proposal and update the current version.
        upgradeProposal = IUpgradeHandler.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        /// Upgrade to the proposed implementation.
        upgradeToAndCall({ newImplementation: proposedImplementation, data: payload });
    }

    /**
     * Defined to allow for the parent contract to implement `_authorizeUpgrade()`.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override;
}
