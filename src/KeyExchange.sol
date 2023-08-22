// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol"; 
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IKeyExchange } from "./interfaces/IKeyExchange.sol";
import { IKeys } from "./interfaces/IKeys.sol";

contract KeyExchange is IKeyExchange, OwnableRoles, EIP712 {
    using ECDSA for bytes32;

    /// @dev keccak256("_ADMIN_ROLE")
    uint256 private constant _ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;

    /// Order(uint256 price,address maker,address taker,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime)
    bytes32 private constant _ORDER_TYPEHASH = 0x9a3b6761b926f38baa0938ef9c869311aed6761ec5857a410ad87bd983171278;
    
    /// Wrapped Ether.
    address private constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 private constant _BASIS_POINTS = 10_000;

    uint256 public protocolFee = 500;

    IKeys public keys;

    mapping(bytes32 orderHash => OrderStatus orderStatus) public orderStatus;
    mapping(uint256 keyId => KeyTerms keyTerms) public keyTerms;

    constructor(address admin_, IKeys keys_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ADMIN_ROLE);
        keys = keys_;
    }

    /**
     * Function used to execute an order.
     */
    function executeOrder(OrderParams calldata orderParams) external payable {
        /// Checks: Ensure that key terms have been defined for the key identifier.
        if (keyTerms[orderParams.order.keyId].market == MarketType.UNDEFINED) revert BuyOutTermsNotDefined();

        /// Cache order.
        Order memory order = orderParams.order;

        /// Recreate the digest.
        bytes32 orderHash = _hashTypedData(keccak256(abi.encode(
            _ORDER_TYPEHASH,
            order.price,
            order.maker,
            order.taker,
            order.keyId,
            order.amount,
            order.nonce,
            order.startTime,
            order.endTime
        )));

        /// Checks: Determine if the order has already been filled.
        if (orderStatus[orderHash] != OrderStatus.OPEN) revert CannotFillOrder();

        /// Checks: Confirm that the signature attached matches the order signer.
        if (orderHash.recover(orderParams.signature) != orderParams.order.maker) revert SignerMismatch();

        /// Checks: Determine if an adequate amount of the native token has been supplied.
        if (msg.value != orderParams.order.price) revert InvalidNativeTokenAmount();

        /// Checks: Determine if a taker has been specified and if the caller is the taker.
        if (orderParams.order.taker != address(0) && msg.sender != orderParams.order.taker) revert CallerNotTaker();

        /// Checks: Determine if the end time for the order has already passed.
        if (block.timestamp > orderParams.order.endTime) revert EndTimePassed();

        /// Transfer asset to user.
        IERC1155(address(keys)).safeTransferFrom({
            from: orderParams.order.maker,
            to: orderParams.order.taker,
            id: orderParams.order.keyId,
            value: orderParams.order.amount,
            data: ""
        });

        /// Pay maker.
        (bool success,) = orderParams.order.maker.call{value: msg.value}("");
        if (!success) revert NativeTransferFailed();
    }

    /**
     * Function used to cancel an order. This function should only be called if a price increase
     * is made.
     */
    function cancelOrders(OrderParams[] calldata orders) external {
        /// Checks: Ensure a non-zero amount of orders have been provided.
        if (orders.length == 0) revert ZeroOrderAmount();

        /// Iterate through each order.
        for (uint256 i = 0; i < orders.length; i++) {
            _cancelOrder(orders[i].order);
        }
    }

    /**
     * Function used to execute a buy back from a list of holders.
     * @param keyId Unique key identifier.
     * @param holders Holders of the associated key
     * @param amounts Number of keys to buy back.
     */
    function executeBuyBack(uint256 keyId, address[] calldata holders, uint256[] calldata amounts) external payable {
        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keys.creatorOf(keyId)) revert NotKeyCreator();

        /// Checks: Ensure the holders array length matches the amounts array length.
        if (holders.length != amounts.length) revert ArrayLengthMismatch();

        /// Checks: Ensure a valid number of holders have been provided.
        if (holders.length == 0) revert NoHoldersProvided();

        /// Copy key terms in to memory.
        KeyTerms memory terms = keyTerms[keyId];

        /// Checks: Ensure buy out terms have been set.
        if (terms.market == MarketType.UNDEFINED) revert TermsNotSet();

        /// Push `msg.value` on to the stack.
        uint256 msgValue = msg.value;

        for (uint256 i = 0; i < holders.length; i++) {
            /// Cache calldata values.
            address holder = holders[i];
            uint256 amount = amounts[i];

            /// Calculate the amount of native token owed to the holder.
            uint256 owedAmount = terms.buyBack * amount;

            /// Deduct owed amount from `msgValue`.
            msgValue -= owedAmount;

            /// Transfer the keys from the holder to the caller.
            IERC1155(address(keys)).safeTransferFrom({
                from: holder,
                to: msg.sender,
                id: keyId,
                value: amount,
                data: ""
            });

            /// Transfer the owed amount of funds to the holder.
            /// TODO: Implement WETH wrap and transfer on failure to prevent DoS.
            (bool success,) = holder.call{value: owedAmount}("");
            if (!success) revert BuyOutTransferFailed();
        }

        /// Checks: Ensure the full amount of native token was provided.
        if (msgValue != 0) revert InvalidNativeTokenAmount();
    }

    /**
     * Function used to define a keys associated buy back terms.
     * @param finalTerms Final buy out terms associated with the key idenitifier.
     * @param keyId Unique key identifier.
     * @dev This function can only be called once and is required to facilitate trading.
     */
    function setKeyTerms(KeyTerms calldata finalTerms, uint256 keyId) external {
        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keys.creatorOf(keyId)) revert NotKeyCreator();

        /// Checks: Ensure that a valid market type has been provided.
        if (finalTerms.market == MarketType.UNDEFINED) revert InvalidMarketType();

        /// Checks: Ensure key terms have not already been set.
        if (keyTerms[keyId].market != MarketType.UNDEFINED) revert TermsSet();

        /// Checks: Ensure valid buy out terms have been provided.
        if (finalTerms.buyBack == 0 || finalTerms.reserve == 0) revert ZeroTermValues();

        /// Checks: Ensure the buy back price is greater than the reserve price.
        /// TODO: Should reserve price be higher than the buy back price?
        // if (finalTerms.buyBack > finalTerms.reserve) revert InvalidBuyOutTerms();

        /// Set the buy out terms in storage.
        keyTerms[keyId] = finalTerms;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _cancelOrder(Order calldata order) internal {
        /// Checks: Ensure the caller is the maker of the order.
        if (order.maker != msg.sender) revert CallerNotMaker();

        /// Recreate the digest.
        bytes32 orderHash = _hashTypedData(keccak256(abi.encode(
            _ORDER_TYPEHASH,
            order.price,
            order.maker,
            order.taker,
            order.keyId,
            order.amount,
            order.nonce,
            order.startTime,
            order.endTime
        )));

        /// Checks: Ensure the order isn't already cancelled or filled.
        if (orderStatus[orderHash] != OrderStatus.OPEN) revert CannotCancelOrder();

        /// Cancel the order by updating its status to cancelled.
        orderStatus[orderHash] = OrderStatus.CANCELLED;

        /// Emit event for order cancellation.
        emit OrderCancelled(orderHash);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EIP712                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Overriden as required in Solady EIP712 documentation.
     */
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "Key Exchange";
        version = "1.0";
    }

}