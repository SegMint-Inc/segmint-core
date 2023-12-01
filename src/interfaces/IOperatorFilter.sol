// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IOperatorFilter
 */
interface IOperatorFilter {
    /**
     * Thrown when the operator is blocked.
     */
    error OperatorBlocked();

    /**
     * Emitted when an operators status is updated.
     * @param operator Address of the operator.
     * @param status Flag indicating whether the operator is blocked or not.
     */
    event OperatorStatusUpdated(address operator, bool status);
}
