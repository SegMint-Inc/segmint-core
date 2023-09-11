// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IOperatorFilter } from "../interfaces/IOperatorFilter.sol";

/**
 * @title OperatorFilter
 * @notice This contract manages the filtering of operators on the ERC1155 keys contract. If an operator has been
 * blocked, it should not be able to move keys on behalf of a user.
 */

abstract contract OperatorFilter is IOperatorFilter {
    /// Maps an operator address to a flag determining if the operator is blocked.
    mapping(address operator => bool blocked) public isOperatorBlocked;

    /**
     * Modifier used to check if the operator is blocked.
     */
    modifier filterOperator(address operator) {
        /// Checks: Ensure the operator address is not blocked.
        if (isOperatorBlocked[operator]) revert OperatorBlocked();
        _;
    }

    /**
     * Function used to block an operator.
     * @param operator Address of the operator.
     * @param status Flag indicating whether the operator is blocked or not.
     */
    function _updateOperatorStatus(address operator, bool status) internal {
        isOperatorBlocked[operator] = status;
        emit OperatorStatusUpdated({ operator: operator, status: status });
    }
}