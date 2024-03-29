// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IKeyExchange
 */
interface IKeyExchange {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when attempting to set the terms for a key that the caller did not create.
     */
    error CallerNotKeyCreator();

    /**
     * Thrown when attempting to set terms for a key that already has terms defined.
     */
    error KeyTermsDefined();

    /**
     * Thrown when attempting to trade a key that has no terms defined.
     */
    error InvalidKeyMarket();

    /**
     * Thrown when trying to set the terms for a buyout market key with a zero buyback or reserve price.
     */
    error InvalidBuyOutTerms();

    /**
     * Thrown when trying to set the terms for a free market key with a non zero buyback and reserve price.
     */
    error InvalidFreeMarketTerms();

    /**
     * Thrown when the buy back price exceeds the reserve price.
     */
    error BuyBackExceedsReserve();

    /**
     * Thrown when an invalid amount of native token has been provided.
     */
    error InvalidNativeTokenAmount();

    /**
     * Thrown when two arrays share different sizes.
     */
    error ArrayLengthMismatch();

    /**
     * Thrown when trying to set buy out terms with an invalid market type.
     */
    error InvalidMarketType();

    /**
     * Thrown when the recovered signer does not match the maker.
     */
    error SignerNotMaker();

    /**
     * Thrown when an order or bid is attempting to be filled after the end time has passed.
     */
    error ExpiredOrderOrBid();

    /**
     * Thrown when an order or bid is attempting to be filled prior to the start time.
     */
    error InactiveOrderOrBid();

    /**
     * Thrown when an order taker has been specified, but the caller is not the taker.
     */
    error CallerNotTaker();

    /**
     * Thrown when the caller is not the creator of an order.
     */
    error CallerNotMaker();

    /**
     * Thrown when trying to cancel an order that is not in the open status.
     */
    error InvalidOrderStatus();

    /**
     * Thrown when trying to cancel a bid that is not in the open status.
     */
    error InvalidBidStatus();

    /**
     * Thrown when trying to execute a buy back with a free market type key.
     */
    error KeyNotBuyOutMarket();

    /**
     * Thrown when a transfer of native token amount fails.
     */
    error NativeTransferFailed();

    /**
     * Thrown when the new protocol fee exceeds the maximum number of basis points.
     */
    error FeeExceedsBps();

    /**
     * Thrown when attempting to transact multi-asset vault keys while they are restricted.
     */
    error MultiAssetKeysRestricted();

    /**
     * Thrown when a parameter array has a zero length.
     */
    error ZeroLengthArray();

    /**
     * Thrown when a buy back doesn't result in the caller owning the total supply of keys.
     */
    error BuyBackFailed();

    /**
     * Thrown when a restricted user attempts to use the Key Exchange whilst restricted users are block.
     */
    error Restricted();

    /**
     * Thrown when a holder has no keys.
     */
    error NoKeysHeld();

    /**
     * Thrown when the zero address is provided.
     */
    error ZeroAddressInvalid();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when an order is filled.
     * @param taker Account that filled the order.
     * @param orderHash EIP712 hash of the order.
     */
    event OrderFilled(address indexed taker, bytes32 orderHash);

    /**
     * Emitted when a bid is filled.
     * @param taker Account that accepted the bid.
     * @param bidHash EIP712 hash of the bid.
     */
    event BidFilled(address indexed taker, bytes32 bidHash);

    /**
     * Emitted when an order is cancelled.
     * @param orderHash EIP712 hash of the order.
     */
    event OrderCancelled(bytes32 orderHash);

    /**
     * Emitted when a bid is cancelled.
     * @param bidHash EIP712 hash of the bid.
     */
    event BidCancelled(bytes32 bidHash);

    /**
     * Emitted when a key buyout at the buy back price is executed.
     * @param caller Account that executed the buy out.
     * @param keyId Unique key idenitfier.
     */
    event BuyOutExecuted(address indexed caller, uint256 indexed keyId);

    /**
     * Emitted when a key buyout at the reserve price is executed.
     * @param caller Account that executed the reserve purchase.
     * @param keyId Unique key identifier.
     */
    event ReserveBuyOut(address indexed caller, uint256 indexed keyId);

    /**
     * Emitted when the protocol fee is updated.
     * @param oldFee Old protocol fee.
     * @param newFee New protocol fee.
     */
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);

    /**
     * Emitted when key terms are set.
     * @param keyId Unique key identifier.
     * @param keyTerms Final key terms.
     */
    event KeyTermsSet(uint256 indexed keyId, KeyTerms keyTerms);

    /**
     * Emitted when multi-key trading status is updated.
     * @param newStatus Flag indicating if multi-key trading is enabled.
     */
    event MultiKeyTradingUpdated(bool newStatus);

    /**
     * Emitted when restricted users access is updated.
     * @param newStatus Flag indiciating is restricted users can access the Key Exchange.
     */
    event RestrictedUserAccessUpdated(bool newStatus);

    /**
     * Emitted when the fee receiver is updated.
     * @param oldFeeReceiver Old protocol fee receiver.
     * @param newFeeReceiver New protocol fee receiver.
     */
    event FeeReceiverUpdated(address oldFeeReceiver, address newFeeReceiver);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the market type associated with a listing.
     * @custom:param FREE: The lister cannot perform a buy out at a later point in time.
     * @custom:param BUYOUT: The lister has the ability to buy the key back at some point in the future.
     * @custom:param INACTIVE: This market type specifies that a key ID has been bought out.
     */
    enum MarketType {
        UNDEFINED,
        FREE,
        BUYOUT,
        INACTIVE
    }

    /**
     * Enum encapsulating the possible statuses that can be associated with an order or bid.
     * @custom:param OPEN: The order or bid can be filled.
     * @custom:param FILLED: The order or bid has been filled.
     * @custom:param CANCELLED: The order or bid has been cancelled.
     */
    enum Status {
        OPEN,
        FILLED,
        CANCELLED
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating all information related to an order.
     * @param market Type of market this listing is associated with, either free or buy-out.
     */
    struct KeyTerms {
        MarketType market;
        uint256 buyBack;
        uint256 reserve;
    }

    /**
     * Struct encapsulating all royalty payment information.
     */
    struct Royalties {
        address receiver;
        uint256 fee;
    }

    /**
     * Struct encapsulating all data related to an order.
     * @param price Total price of the order.
     * @param maker Address of the account that created the order.
     * @param taker Address of the account that the order is destined for, `address(0)` means an open order.
     * @param keyId Key identifier associated with this order.
     * @param amount Number of keys available to purchase.
     * @param nonce Nonce of the maker at the time this order was created.
     * @param startTime Timestamp that this order was created.
     * @param endTime Timestamp that this order will become invalid.
     * @param protocolFee Protocol fee at the time the order was created.
     */
    struct Order {
        uint256 price;
        address maker;
        address taker;
        uint256 keyId;
        uint256 amount;
        uint256 nonce;
        uint256 startTime;
        uint256 endTime;
        uint256 protocolFee;
        Royalties[] royalties;
    }

    /**
     * Struct encapsulating all data related to a bid.
     * @param maker Address of the account that created the bid.
     * @param price Total bid amount.
     * @param keyId Key identifier associated with this bid.
     * @param amount Number of keys the bidder wishes to purchase.
     * @param nonce Nonce of the bidder at the time this order was created.
     * @param startTime Timestamp that this bid was created.
     * @param endTime Timestamp that this bid will become invalid.
     * @param protocolFee Protocol fee at the time the order was created.
     */
    struct Bid {
        address maker;
        uint256 price;
        uint256 keyId;
        uint256 amount;
        uint256 nonce;
        uint256 startTime;
        uint256 endTime;
        uint256 protocolFee;
        Royalties[] royalties;
    }

    /**
     * Struct encapsulating the order and the signature associated with it.
     * @param order Complete `Order` struct.
     * @param signature Signed EIP712 order digest.
     */
    struct OrderParams {
        Order order;
        bytes signature;
    }

    /**
     * Struct encapsulating the bid and the signature associated with it.
     * @param bid Complete `bid` struct.
     * @param signature Signed EIP712 bid digest.
     */
    struct BidParams {
        Bid bid;
        bytes signature;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to execute an array of orders.
     * @param orders Array of orders to execute.
     */
    function executeOrders(OrderParams[] calldata orders) external payable;

    /**
     * Function used to execute an array of bids.
     * @param bids Array of bids to execute.
     */
    function executeBids(BidParams[] calldata bids) external;

    /**
     * Function used to cancel an array of orders.
     * @param orders Array of orders to cancel.
     */
    function cancelOrders(Order[] calldata orders) external;

    /**
     * Function used to cancel an array of bids.
     * @param bids Array of bids to cancel.
     */
    function cancelBids(Bid[] calldata bids) external;

    /**
     * Function used to execute a buy back of all keys from existing holders.
     * @param keyId Unique key idenitifier.
     * @param holders Array of holders to purchase the keys from.
     */
    function executeBuyBack(uint256 keyId, address[] calldata holders) external payable;

    /**
     * Function used to purchase keys at the reserve price from existing holders.
     * @param keyId Unique key idenitifier.
     * @param holders Array of holders to purchase the keys from.
     */
    function buyAtReserve(uint256 keyId, address[] calldata holders) external payable;

    /**
     * Function used to set the key terms associated with a key idenitifier.
     * @param finalTerms The terms associated with the key ID.
     * @param keyId Unique key idenitifier.
     */
    function setKeyTerms(uint256 keyId, KeyTerms calldata finalTerms) external;

    /**
     * Function used to toggle trading of multi-asset vault keys.
     */
    function toggleMultiKeyTrading() external;

    /**
     * Function used to toggle access to the Key Exchange for restricted users.
     */
    function toggleAllowRestrictedUsers() external;

    /**
     * Function used to adjust the currently defined protocol fee percentage.
     * @param newProtocolFee New protocol fee value.
     */
    function setProtocolFee(uint256 newProtocolFee) external;

    /**
     * Function used to set a new fee receiver address.
     * @param newFeeReceiver New protocol fee receiver.
     */
    function setFeeReceiver(address newFeeReceiver) external;

    /**
     * Function used to view the terms associated with a given key identifier.
     * @param keyId Unique key idenitifier.
     */
    function keyTerms(uint256 keyId) external view returns (KeyTerms memory);

    /**
     * Function used to increment the nonce associated with the caller.
     */
    function incrementNonce() external;

    /**
     * Function used to view the nonce associated with a given account.
     * @param account The account to view the current nonce value for.
     */
    function getNonce(address account) external view returns (uint256);

    /**
     * Function used to view the EIP712 hash of an Order struct.
     * @param order Order struct to hash.
     */
    function hashOrder(Order calldata order) external view returns (bytes32);

    /**
     * Function used to view the EIP712 hash of a Bid struct.
     * @param bid Bid struct to hash.
     */
    function hashBid(Bid calldata bid) external view returns (bytes32);
}
