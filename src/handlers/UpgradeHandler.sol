// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import { IUpgradeHandler } from "../interfaces/IUpgradeHandler.sol";

/**
 * @title UpgradeHandler
 * @notice This contract is responsible for handling any upgrades that are proposed to the inheriting
 * contract, it does so with a timelock whereby the duration is defined by `UPGRADE_TIMELOCK`.
 */

abstract contract UpgradeHandler is IUpgradeHandler, UUPSUpgradeable {
    /// Implementation upgrade proposals cannot be executed for 5 days.
    uint256 public constant UPGRADE_TIMELOCK = 5 days;

    /// The current upgrade proposal.
    IUpgradeHandler.UpgradeProposal public upgradeProposal;

    /**
     * Function used to propose an upgrade to the implementation address.
     * @param newImplementation The new implementation address.
     */
    function _proposeUpgrade(address newImplementation) internal {
        /// Checks: Ensure that a proposal is not currently in progress.
        if (upgradeProposal.deadline != 0) revert ProposalInProgress();

        uint40 proposalDeadline = uint40(block.timestamp + UPGRADE_TIMELOCK);

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

    /**
     * Function used to cancel an upgrade proposal.
     */
    function _cancelUpgrade() internal {
        /// Checks: Ensure there is a proposal to cancel.
        if (upgradeProposal.deadline == 0) revert NoProposalExists();

        address proposedImplementation = upgradeProposal.newImplementation;
        upgradeProposal = IUpgradeHandler.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        emit IUpgradeHandler.UpgradeCancelled({ admin: msg.sender, implementation: proposedImplementation });
    }

    /**
     * Function used to execute an upgrade to the implementation address.
     * @param payload Encoded calldata to forward to the implementation address upon upgrade.
     */
    function _executeUpgrade(bytes memory payload) internal {
        /// Checks: Ensure the proposed implementation is non-zero.
        if (upgradeProposal.newImplementation == address(0)) revert NoProposalExists();

        /// Checks: Ensure the timelock duration has lapsed.
        if (upgradeProposal.deadline > block.timestamp) revert UpgradeTimeLocked();

        address proposedImplementation = upgradeProposal.newImplementation;

        /// Clear the previous upgrade proposal and update the current version.
        upgradeProposal = IUpgradeHandler.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        /// Upgrade to the proposed implementation address.
        _upgradeToAndCallUUPS({ newImplementation: proposedImplementation, data: payload, forceCall: false });
    }

    /**
     * @dev Defined to allow for the inheriting contract to implement `_authorizeUpgrade()`.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override;
}
