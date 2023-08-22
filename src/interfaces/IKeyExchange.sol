// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IKeyExchange {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when attempting to set buy out terms for a key the caller did not create.
     */
    error NotKeyCreator();

    /**
     * Thrown when the buy out terms for a key have already been set.
     */
    error TermsSet();

    /**
     * Thrown when the buy out terms for a key have not been set.
     */
    error TermsNotSet();

    /**
     * Thrown when a zero value of buy terms has been provided.
     */
    error ZeroTermValues();

    /**
     * Thrown when the buy back price is greater than the reserve price.
     */
    error InvalidBuyOutTerms();

    /**
     * Thrown when no holders are provided for a buy back.
     */
    error NoHoldersProvided();

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
     * Thrown when trying to execute an order where terms have not been defined.
     */
    error BuyOutTermsNotDefined();

    /**
     * Thrown when a buy out transfer fails.
     */
    error BuyOutTransferFailed();

    /**
     * Thrown when the signature provided does not match the order type hash.
     */
    error SignerMismatch();

    /**
     * Thrown when an order is attempted to be filled after the end time.
     */
    error EndTimePassed();

    /**
     * Thrown when an order taker has been specified, but the caller is not the taker.
     */
    error CallerNotTaker();

    /**
     * Thrown when the caller is not the creator of an order.
     */
    error CallerNotMaker();

    error ZeroOrderAmount();

    error OrderFilled();

    error CannotFillOrder();

    error CannotCancelOrder();

    error NativeTransferFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event OrderIsFilled();

    event OrderCancelled(bytes32 orderHash);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the market type associated with a listing.
     * @custom:param FREE: The lister cannot perform a buy out at a later point in time.
     * @custom:param BUY_OUT: The lister has the ability to buy the key back at some point in the future.
     */
    enum MarketType {
        UNDEFINED,
        FREE,
        BUY_OUT
    }

    enum OrderStatus {
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
     * Struct encapsulating all information related to an order.
     * @param price Price of the order.
     * @param maker Address of the user that created the ask order.
     * @param taker Used for private sales, taker is the address of the buyer this order was intended for.
     * @param keyId Unique key idenitifer.
     * @param amount Number of keys to list for sale.
     * @param nonce Used for invalidating previous versions of this order incase listing prices are updated.
     * @param startTime Timestamp this order was created.
     * @param endTime Timestamp this order will expire.
     */

    // Order(uint256 price,address maker,address taker,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime)
    struct Order {
        uint256 price;
        address maker;
        address taker;
        uint256 keyId;
        uint256 amount;
        uint256 nonce;
        uint256 startTime;
        uint256 endTime;
    }

    struct OrderParams {
        Order order;
        bytes signature;
    }

}