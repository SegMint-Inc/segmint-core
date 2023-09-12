// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IOperatorFilter } from "../interfaces/IOperatorFilter.sol";

/**
 * @title OperatorFilter
 * @notice This contract manages the filtering of operators on the ERC1155 keys contract. If an operator has been
 * blocked, it should not be able to move keys on behalf of a user.
 */

abstract contract OperatorFilter is IOperatorFilter {
    mapping(address operator => bool blocked) public isOperatorBlocked;

    modifier filterOperatorApproval(address operator) {
        _checkOperatorStatus(operator);
        _;
    }

    modifier filterOperator(address operator) {
        if (msg.sender != operator) _checkOperatorStatus(msg.sender);
        _;
    }

    /**
     * Function used to block an operator.
     * @param operator Address of the operator.
     * @param isBlocked Flag indicating if the operator is blocked or not.
     */
    function _updateOperatorStatus(address operator, bool isBlocked) internal {
        isOperatorBlocked[operator] = isBlocked;
        emit OperatorStatusUpdated({ operator: operator, status: isBlocked });
    }

    /**
     * Function used to check if an operator is blocked.
     */
    function _checkOperatorStatus(address operator) internal view {
        /// Checks: Ensure the operator address is not blocked.
        if (isOperatorBlocked[operator]) revert OperatorBlocked();
    }
}
