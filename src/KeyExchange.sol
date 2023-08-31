// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { NonceManager } from "./managers/NonceManager.sol";
import { IKeyExchange } from "./interfaces/IKeyExchange.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { VaultType, KeyConfig } from "./types/DataTypes.sol";

contract KeyExchange is IKeyExchange, OwnableRoles, NonceManager, EIP712 {
    using ECDSA for bytes32;

    /// @dev keccak256("_ADMIN_ROLE")
    uint256 private constant _ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;

    /// Order(uint256 price,address maker,address taker,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime)
    bytes32 private constant _ORDER_TYPEHASH = 0x9a3b6761b926f38baa0938ef9c869311aed6761ec5857a410ad87bd983171278;

    /// Bid(address maker,uint256 price,uint256 keyId,uint256 amount,uint256 startTime,uint256 endTime)
    bytes32 private constant _BID_TYPEHASH = 0xdf9d101dd2b60a9a7812e3b3efb62d0f6bbe4d5dbcc3c96268ee8c3f393dd534;
    
    /// Used for fee calculation.
    uint256 private constant _BASIS_POINTS = 10_000;

    /// Amount of gas to be forwarded with native token transfers.
    uint256 private constant _GAS_LIMIT_TRANSFER = 2_300;

    /// Wrapped Ether.
    address private immutable _WETH;

    uint256 public protocolFee = 500;
    address public feeReceiver;
    bool public multiKeysRestricted = true;

    IKeys public keys;

    mapping(bytes32 orderHash => Status orderStatus) public orderStatus;
    mapping(bytes32 bidHash => Status orderStatus) public bidStatus;
    mapping(uint256 keyId => KeyTerms keyTerms) public keyTerms;

    constructor(address admin_, IKeys keys_, address feeReceiver_, address weth_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ADMIN_ROLE);

        keys = keys_;
        feeReceiver = feeReceiver_;

        _WETH = weth_;
    }

    function executeOrders(OrderParams[] calldata orders) external payable {
        /// Checks: Ensure a non-zero amount of orders have been specified.
        if (orders.length == 0) revert NoOrdersProvided();

        /// Push initial `msg.value` to the stack.
        uint256 msgValue = msg.value;

        for (uint256 i = 0; i < orders.length; i++) {
            OrderParams calldata singleOrder = orders[i];
            
            /// Validates the order criteria.
            _validateOrderCriteria(singleOrder);

            /// Transfer asset to caller.
            IERC1155(address(keys)).safeTransferFrom({
                from: singleOrder.order.maker,
                to: msg.sender,
                id: singleOrder.order.keyId,
                value: singleOrder.order.amount,
                data: ""
            });

            /// Pay protocol fee and maker.
            _payFeesAndMaker(singleOrder.order);

            /// Deduct the order price from the stored native token value.
            msgValue -= singleOrder.order.price;
        }

        /// If some amount of native token remains, refund the caller.
        if (msgValue > 0) {
            (bool refundSent,) = msg.sender.call{ gas: _GAS_LIMIT_TRANSFER, value: msgValue }("");
            if (!refundSent) revert NativeTransferFailed();
        }
    }

    /**
     * Function used to execute a bid.
     */
    function executeBid(BidParams calldata bidParams) external {
        /// Cache bid.
        Bid memory bid = bidParams.bid;

        /// Checks: Ensure that key terms have been defined for the key identifier.
        if (keyTerms[bid.keyId].market == MarketType.UNDEFINED) revert BuyOutTermsNotDefined();

        /// Recreate the digest.
        bytes32 bidHash = _hashTypedData(
            keccak256(
                abi.encode(
                    _BID_TYPEHASH,
                    bid.maker,
                    bid.price,
                    bid.keyId,
                    bid.amount,
                    _nonces[bid.maker],
                    bid.startTime,
                    bid.endTime
                )
            )
        );

        /// Checks: Determine if the order has already been filled.
        if (bidStatus[bidHash] != Status.OPEN) revert CannotFillOrder();

        /// Checks: Confirm that the signature attached matches the order signer.
        if (bidHash.recover(bidParams.signature) != bid.maker) revert SignerMismatch();

        /// Checks: Determine if the end time for the order has already passed.
        if (block.timestamp > bid.endTime) revert EndTimePassed();

        /// Acknowledge the bid will be filled.
        bidStatus[bidHash] = IKeyExchange.Status.FILLED;

        /// Transfer assets to the bid offerer.
        IERC1155(address(keys)).safeTransferFrom({
            from: msg.sender,
            to: bid.maker,
            id: bid.keyId,
            value: bid.amount,
            data: ""
        });

        /// Calculate protocol fee.
        uint256 fee = bid.price * protocolFee / _BASIS_POINTS;
        uint256 earnings = bid.price - fee;

        /// Pay protocol fee.
        bool success = IWETH(_WETH).transferFrom(bid.maker, feeReceiver, fee);
        if (!success) revert NativeTransferFailed();

        /// Pay maker.
        success = IWETH(_WETH).transferFrom(bid.maker, msg.sender, earnings);
        if (!success) revert NativeTransferFailed();
    }

    /**
     * Function used to cancel an order.
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
     * Function used to cancel bids.
     */
    function cancelBids(BidParams[] calldata bids) external {
        /// Checks: Ensure a non-zero amount of bids have been provided.
        if (bids.length == 0) revert IKeyExchange.ZeroLengthArray();

        /// Iterate through each bid.
        for (uint256 i = 0; i < bids.length; i++) {
            _cancelBid(bids[i].bid);
        }
    }

    /**
     * Function used to execute a buy back from a list of holders.
     * @param keyId Unique key identifier.
     * @param holders Holders of the associated key
     * @param amounts Number of keys to buy back.
     */
    /// NOTE: Discuss how potential DoS attacks can be mitigated.
    function executeBuyBack(uint256 keyId, address[] calldata holders, uint256[] calldata amounts) external payable {
        /// Cache key configuration in memory.
        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);

        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keyConfig.creator) revert NotKeyCreator();

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
            IERC1155(address(keys)).safeTransferFrom({ from: holder, to: msg.sender, id: keyId, value: amount, data: "" });

            /// Transfer the owed amount of funds to the holder.
            /// TODO: Implement WETH wrap and transfer on failure to prevent DoS.
            (bool success,) = holder.call{ value: owedAmount }("");
            if (!success) revert BuyOutTransferFailed();
        }

        /// Checks: Ensure the full amount of native token was provided.
        if (msgValue != 0) revert InvalidNativeTokenAmount();

        /// Checks: Ensure all keys were successfully transferred to the holder.
        uint256 keysHeld = IERC1155(address(keys)).balanceOf(msg.sender, keyId);
        if (keysHeld != keyConfig.supply) revert BuyBackFailed();
    }

    function setProtocolFee(uint256 newProtocolFee) external onlyRoles(_ADMIN_ROLE) {
        if (newProtocolFee > _BASIS_POINTS) revert FeeExceedsMaximum();
        protocolFee = newProtocolFee;
    }

    /**
     * Function used to define a keys associated buy back terms.
     * @param finalTerms Final buy out terms associated with the key idenitifier.
     * @param keyId Unique key identifier.
     * @dev This function can only be called once and is required to facilitate trading.
     * Reserve price should be higher than the buy out price.
     */
    function setKeyTerms(KeyTerms calldata finalTerms, uint256 keyId) external {
        /// Cache key configuration in memory.
        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);

        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keyConfig.creator) revert NotKeyCreator();

        /// Checks: Ensure that a valid market type has been provided.
        if (finalTerms.market == MarketType.UNDEFINED) revert InvalidMarketType();

        /// Checks: Ensure key terms have not already been set.
        if (keyTerms[keyId].market != MarketType.UNDEFINED) revert TermsSet();

        /// Checks: Ensure valid buy out terms have been provided.
        if (finalTerms.buyBack == 0 || finalTerms.reserve == 0) revert ZeroTermValues();

        /// Checks: Ensure the buy back price is greater than the reserve price.
        if (finalTerms.buyBack > finalTerms.reserve) revert InvalidBuyOutTerms();

        /// Set the buy out terms in storage.
        keyTerms[keyId] = finalTerms;
    }

    /**
     * Function used to increment the nonce associated with the caller. Doing so will invalidate
     * ALL orders and bids associated with the caller.
     */
    function incrementNonce() external {
        _incrementNonce();
    }

    /**
     * Function used to view the current nonce associated with the provided account.
     */
    function getNonce(address account) external view returns (uint256) {
        return _getNonce(account);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _cancelOrder(Order calldata order) internal {
        /// Checks: Ensure the caller is the maker of the order.
        if (order.maker != msg.sender) revert CallerNotMaker();

        /// Recreate the digest.
        bytes32 orderHash = _hashTypedData(
            keccak256(
                abi.encode(
                    _ORDER_TYPEHASH,
                    order.price,
                    order.maker,
                    order.taker,
                    order.keyId,
                    order.amount,
                    order.nonce,
                    order.startTime,
                    order.endTime
                )
            )
        );

        /// Checks: Ensure the order isn't already cancelled or filled.
        if (orderStatus[orderHash] != Status.OPEN) revert CannotCancelOrder();

        /// Cancel the order by updating its status to cancelled.
        orderStatus[orderHash] = Status.CANCELLED;

        /// Emit event for order cancellation.
        emit OrderCancelled(orderHash);
    }

    function _cancelBid(Bid calldata bid) internal {
        /// Checks: Ensure the caller is the maker of the order.
        if (bid.maker != msg.sender) revert CallerNotMaker();

        /// Recreate the digest.
        bytes32 bidHash = _hashTypedData(
            keccak256(
                abi.encode(_BID_TYPEHASH, bid.maker, bid.price, bid.keyId, bid.amount, bid.startTime, bid.endTime)
            )
        );

        /// Checks: Ensure the bid isn't cancelled of filled.
        if (bidStatus[bidHash] != Status.OPEN) revert CannotCancelBid();

        /// Cancel the bid by updating its status.
        bidStatus[bidHash] = Status.CANCELLED;

        /// Emit event for bid cancellation.
        emit BidCancelled(bidHash);
    }

    function _validateOrderCriteria(OrderParams calldata singleOrder) internal {
        /// Recreate the original order digest.
        bytes32 orderHash = _hashTypedData(keccak256(abi.encode(
            _ORDER_TYPEHASH,
            singleOrder.order.price,
            singleOrder.order.maker,
            singleOrder.order.taker,
            singleOrder.order.keyId,
            singleOrder.order.amount,
            _nonces[singleOrder.order.maker],
            singleOrder.order.startTime,
            singleOrder.order.endTime
        )));

        /// Checks: Confirm that the signature attached matches the order signer.
        if (orderHash.recover(singleOrder.signature) != singleOrder.order.maker) revert SignerMismatch();

        /// Checks: Ensure that key terms have been defined.
        if (keyTerms[singleOrder.order.keyId].market == MarketType.UNDEFINED) revert BuyOutTermsNotDefined();

        /// Checks: Ensure that multi-asset vault keys can be sold.
        if (
            multiKeysRestricted && keys.getKeyConfig(singleOrder.order.keyId).vaultType == VaultType.MULTI
        ) revert MultiAssetKeysRestricted();

        /// Checks: Determine if the order has already been filled.
        if (orderStatus[orderHash] != Status.OPEN) revert CannotFillOrder();

        /// Checks: Determine if a taker has been specified and if the caller is the taker.
        if (singleOrder.order.taker != address(0) && msg.sender != singleOrder.order.taker) revert CallerNotTaker();

        /// Checks: Determine if the end time for the order has already passed.
        if (block.timestamp > singleOrder.order.endTime) revert EndTimePassed();

        /// Acknowledge that the order will be filled upon success.
        orderStatus[orderHash] = IKeyExchange.Status.FILLED;
    }

    function _payFeesAndMaker(Order calldata singleOrder) internal {
        /// Calculate the protocol fee and subtract from the order price.
        uint256 fee = singleOrder.price * protocolFee / _BASIS_POINTS;
        uint256 earnings = singleOrder.price - fee;

        /// Pay the protocol fee to the fee receiver.
        (bool sentFee,) = feeReceiver.call{ value: fee }("");
        if (!sentFee) revert NativeTransferFailed();

        /// Pay the creator of the order, if the transfer of native token fails, wrap the native token
        /// and transfer to the creator.
        (bool sentEarnings,) = singleOrder.maker.call{ gas: _GAS_LIMIT_TRANSFER, value: earnings }("");
        if (!sentEarnings) {
            IWETH(_WETH).deposit{value: earnings}();
            bool success = IWETH(_WETH).transfer(singleOrder.maker, earnings);
            if (!success) revert NativeTransferFailed();
        }
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

    function hashOrder(Order calldata order) public view returns (bytes32) {
        return _hashTypedData(keccak256(abi.encode(
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
    }

    function hashBid(Bid calldata bid) public view returns (bytes32) {
        return _hashTypedData(keccak256(abi.encode(
            _BID_TYPEHASH,
            bid.maker,
            bid.price,
            bid.keyId,
            bid.amount,
            bid.nonce,
            bid.startTime,
            bid.endTime
        )));
    }
}
