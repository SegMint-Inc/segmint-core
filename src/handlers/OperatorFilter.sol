// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { IOperatorFilter } from "../interfaces/IOperatorFilter.sol";

/**
 * @title OperatorFilter
 * @notice This contract manages the filtering of operators on the ERC1155 keys contract.
 */
abstract contract OperatorFilter is IOperatorFilter {
    mapping(address operator => bool allowed) public isOperatorAllowed;

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
     * Function used to update an operators status.
     * @param operator Address of the operator.
     * @param isAllowed Flag indicating if the operator is allowed or not.
     */
    function _updateOperatorStatus(address operator, bool isAllowed) internal {
        isOperatorAllowed[operator] = isAllowed;
        emit OperatorStatusUpdated({ operator: operator, status: isAllowed });
    }

    /**
     * Function used to check if an operator is blocked.
     */
    function _checkOperatorStatus(address operator) internal view {
        /// Checks: Ensure the operator address is not blocked.
        if (!isOperatorAllowed[operator]) revert OperatorBlocked();
    }
}
