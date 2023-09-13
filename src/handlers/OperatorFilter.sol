// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IOperatorFilter } from "../interfaces/IOperatorFilter.sol";

/**
 * @title OperatorFilter
 * @notice This contract manages the filtering of operators on the ERC1155 keys contract.
 */
abstract contract OperatorFilter is IOperatorFilter {
    mapping(address operator => bool blocked) public isOperatorBlocked;

    /**
     * Modifier used to validate an operator address when {IERC1155.setApprovalForAll} is called.
     */
    modifier filterOperatorApproval(address operator) {
        _checkOperatorStatus(operator);
        _;
    }

    /**
     * Modifier used to validate an operator address when either {IERC1155.safeTransferFrom}
     * or {IERC1155.safeBatchTransferFrom} is called.
     */
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
