// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ExchangeHasher } from "./handlers/ExchangeHasher.sol";
import { NonceManager } from "./managers/NonceManager.sol";
import { IKeyExchange } from "./interfaces/IKeyExchange.sol";
import { IAccessRegistry } from "./interfaces/IAccessRegistry.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { VaultType, KeyConfig } from "./types/DataTypes.sol";

contract KeyExchange is IKeyExchange, OwnableRoles, NonceManager, ExchangeHasher {
    using ECDSA for bytes32;

    /// @dev Total basis points used for fee calculation.
    uint256 private constant _BASIS_POINTS = 10_000;

    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    /// @dev Wrapped native token contract.
    IWETH public immutable WETH;

    IKeys public keys;
    IAccessRegistry public accessRegistry;

    /// Default protocol fee to 05.00%
    uint256 public protocolFee = 500;
    address public feeReceiver;

    /// Flag indicating if multi-asset vault keys are tradable.
    bool public multiKeysTradable;

    /// Flag indicating if restricted users can trade via the exchange.
    bool public allowRestrictedUsers;

    mapping(bytes32 orderHash => Status status) public orderStatus;
    mapping(bytes32 bidHash => Status status) public bidStatus;
    mapping(uint256 keyId => KeyTerms keyTerms) private _keyTerms;

    constructor(address admin_, address feeReceiver_, address weth_, IKeys keys_, IAccessRegistry accessRegistry_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        WETH = IWETH(weth_);
        feeReceiver = feeReceiver_;
        
        keys = keys_;
        accessRegistry = accessRegistry_;
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function executeOrders(OrderParams[] calldata orders) external payable {
        /// Checks: Ensure a non-zero amount of orders have been specified.
        if (orders.length == 0) revert ZeroLengthArray();

        /// Push initial `msg.value` to the stack.
        uint256 msgValue = msg.value;

        /// Tracks the total fees to be paid for all orders.
        uint256 totalFees = 0;

        for (uint256 i = 0; i < orders.length; i++) {
            /// Cache respective order parameters.
            Order calldata order = orders[i].order;
            bytes calldata signature = orders[i].signature;

            /// Checks: Ensure that the key terms have been defined for the associated key ID.
            if (_keyTerms[order.keyId].market == MarketType.UNDEFINED) revert KeyTermsUndefined();

            /// Get the EIP712 digest of the provided order.
            bytes32 orderHash = _hashOrder(order);

            /// Checks: Determine if the order has a valid status.
            if (orderStatus[orderHash] != Status.OPEN) revert InvalidOrderStatus();

            /// Checks: Confirm that the signature attached matches the order maker.
            if (orderHash.recover(signature) != order.maker) revert SignerNotMaker();

            /// Checks: Determine if a taker has been specified and if the caller is the taker.
            if (order.taker != address(0) && msg.sender != order.taker) revert CallerNotTaker();

            /// Checks: Ensure bid start time has elapsed.
            if (block.timestamp < order.startTime) revert InactiveOrderOrBid();

            /// Checks: Ensure bid end time hasn't passed.
            if (block.timestamp > order.endTime) revert ExpiredOrderOrBid();

            /// Acknowledge that the order will be filled upon success.
            orderStatus[orderHash] = Status.FILLED;

            /// Transfer keys to caller.
            IERC1155(address(keys)).safeTransferFrom(order.maker, msg.sender, order.keyId, order.amount, "");

            /// Calculate the protocol fee and subtract from the order price.
            uint256 calculatedFee = order.price * protocolFee / _BASIS_POINTS;
            uint256 makerEarnings = order.price - calculatedFee;

            /// Update the total amount of native token to pay the protocol.
            totalFees += calculatedFee;

            /// Pay the maker earnings, forward a sufficient amount of gas.
            (bool success,) = order.maker.call{ value: makerEarnings }("");
            if (!success) revert NativeTransferFailed();

            /// Checks: Ensure a sufficient amount of native token has been provided.
            if (order.price > msgValue) revert InvalidNativeTokenAmount();
            msgValue -= order.price;

            /// Emit event after the order has been completely filled.
            emit OrderFilled(orderHash);
        }

        /// Pay the total fee amount to the fee receiver.
        if (totalFees > 0) {
            (bool success,) = feeReceiver.call{ value: totalFees }("");
            if (!success) revert NativeTransferFailed();
        }

        /// If some amount of native token remains, refund to the caller.
        if (msgValue > 0) {
            (bool refunded,) = msg.sender.call{ value: msgValue }("");
            if (!refunded) revert NativeTransferFailed();
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function executeBids(BidParams[] calldata bidParams) external {
        /// Checks: Ensure a non zero amount of bids have been provided.
        if (bidParams.length == 0) revert ZeroLengthArray();

        for (uint256 i = 0; i < bidParams.length; i++) {
            /// Cache respective bid parameters.
            Bid calldata bid = bidParams[i].bid;
            bytes calldata signature = bidParams[i].signature;

            /// Checks: Ensure restricted users can use the Key Exchange.
            IAccessRegistry.AccessType accessType = accessRegistry.accessType(bid.maker);
            if (accessType == IAccessRegistry.AccessType.RESTRICTED && !allowRestrictedUsers) revert RestrictedUsersBlocked();

            /// Checks: Ensure that key terms have been defined for the key identifier.
            if (_keyTerms[bid.keyId].market == MarketType.UNDEFINED) revert KeyTermsUndefined();

            /// Get the EIP712 digest of the provided bid.
            bytes32 bidHash = _hashBid(bid);

            /// Checks: Determine if the bid has already been filled.
            if (bidStatus[bidHash] != Status.OPEN) revert InvalidBidStatus();

            /// Checks: Confirm that the signature attached matches the order signer.
            if (bidHash.recover(signature) != bid.maker) revert SignerNotMaker();

            /// Checks: Ensure bid start time has elapsed.
            if (block.timestamp < bid.startTime) revert InactiveOrderOrBid();

            /// Checks: Ensure bid end time hasn't passed.
            if (block.timestamp > bid.endTime) revert ExpiredOrderOrBid();

            /// Acknowledge the bid will be filled.
            bidStatus[bidHash] = Status.FILLED;

            /// Transfer assets to the bid maker.
            IERC1155(address(keys)).safeTransferFrom(msg.sender, bid.maker, bid.keyId, bid.amount, "");

            /// Calculate protocol fee.
            uint256 calculatedFee = bid.price * protocolFee / _BASIS_POINTS;
            uint256 takerEarnings = bid.price - calculatedFee;

            /// Pay protocol fee.
            bool success = WETH.transferFrom(bid.maker, feeReceiver, calculatedFee);
            if (!success) revert NativeTransferFailed();

            /// Pay bid maker.
            success = WETH.transferFrom(bid.maker, msg.sender, takerEarnings);
            if (!success) revert NativeTransferFailed();

            /// Emit event to acknowledge the bid has been filled.
            emit BidFilled(bidHash);
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function cancelOrders(Order[] calldata orders) external {
        /// Checks: Ensure a non-zero amount of orders have been specified.
        if (orders.length == 0) revert ZeroLengthArray();

        /// Iterate through each order.
        for (uint256 i = 0; i < orders.length; i++) {
            /// Cache order parameter.
            Order calldata order = orders[i];

            /// Checks: Ensure the caller is the maker of the order.
            if (order.maker != msg.sender) revert CallerNotMaker();

            /// Get the EIP712 digest of the provided order.
            bytes32 orderHash = _hashOrder(order);

            /// Checks: Ensure the order isn't already cancelled or filled.
            if (orderStatus[orderHash] != Status.OPEN) revert InvalidOrderStatus();

            /// Cancel the order by updating its status to cancelled.
            orderStatus[orderHash] = Status.CANCELLED;

            /// Emit event for order cancellation.
            emit OrderCancelled(orderHash);
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function cancelBids(Bid[] calldata bids) external {
        /// Checks: Ensure a non-zero amount of bids have been provided.
        if (bids.length == 0) revert ZeroLengthArray();

        /// Iterate through each bid.
        for (uint256 i = 0; i < bids.length; i++) {
            /// Cache bid parameter.
            Bid calldata bid = bids[i];

            /// Checks: Ensure the caller is the maker of the bid.
            if (bid.maker != msg.sender) revert CallerNotMaker();

            /// Get the EIP712 digest of the provided bid.
            bytes32 bidHash = _hashBid(bid);

            /// Checks: Ensure the bid isn't cancelled of filled.
            if (bidStatus[bidHash] != Status.OPEN) revert InvalidBidStatus();

            /// Cancel the bid by updating its status.
            bidStatus[bidHash] = Status.CANCELLED;

            /// Emit event for bid cancellation.
            emit BidCancelled(bidHash);
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function executeBuyBack(uint256 keyId, address[] calldata holders, uint256[] calldata amounts) external payable {
        /// Cache key configuration in memory.
        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);

        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keyConfig.creator) revert CallerNotKeyCreator();

        /// Checks: Ensure a valid number of holders or amounts have been provided.
        if (holders.length == 0 || amounts.length == 0) revert ZeroLengthArray();

        /// Checks: Ensure the holders array length matches the amounts array length.
        if (holders.length != amounts.length) revert ArrayLengthMismatch();

        /// Copy key terms in to memory.
        KeyTerms memory terms = _keyTerms[keyId];

        /// Checks: Ensure buy out terms have been set.
        if (terms.market != MarketType.BUYOUT) revert KeyNotBuyOutMarket();

        /// Push original `msg.value` on to the stack.
        uint256 msgValue = msg.value;

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 amount = amounts[i];

            /// Calculate the amount of native token owed to the holder.
            uint256 earnings = terms.buyBack * amount;

            /// Deduct owed amount from `msgValue`.
            if (earnings > msgValue) revert InvalidNativeTokenAmount();
            msgValue -= earnings;

            /// Transfer the keys from the holder to the caller.
            IERC1155(address(keys)).safeTransferFrom(holder, msg.sender, keyId, amount, "");

            /// Transfer the owed amount of funds to the holder.
            (bool success,) = holder.call{ value: earnings }("");
            if (!success) revert NativeTransferFailed();
        }

        /// Checks: Ensure the full amount of native token was provided.
        if (msgValue != 0) revert InvalidNativeTokenAmount();

        /// Checks: Ensure all keys were successfully transferred to the holder.
        if (IERC1155(address(keys)).balanceOf(msg.sender, keyId) != keyConfig.supply) revert BuyBackFailed();
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function buyAtReserve(uint256 keyId, address[] calldata holders, uint256[] calldata amounts) external payable {
        /// Checks: Ensure a valid number of holders have been provided.
        if (holders.length == 0) revert ZeroLengthArray();

        /// Checks: Ensure the holders array length matches the amounts array length.
        if (holders.length != amounts.length) revert ArrayLengthMismatch();

        /// Copy key terms in to memory.
        KeyTerms memory terms = _keyTerms[keyId];

        /// Checks: Ensure buy out terms have been set.
        if (terms.market != MarketType.BUYOUT) revert KeyNotBuyOutMarket();

        /// Push original `msg.value` on to the stack.
        uint256 msgValue = msg.value;

        for (uint256 i = 0; i < holders.length; i++) {
            /// Cache calldata values.
            address holder = holders[i];
            uint256 amount = amounts[i];

            /// Calculate the amount of native token owed to the holder.
            uint256 owedAmount = terms.reserve * amount;

            /// Deduct owed amount from `msgValue`.
            if (owedAmount > msgValue) revert InvalidNativeTokenAmount();
            msgValue -= owedAmount;

            /// Transfer the keys from the holder to the caller.
            IERC1155(address(keys)).safeTransferFrom(holder, msg.sender, keyId, amount, "");

            /// Transfer the owed amount of funds to the holder.
            (bool success,) = holder.call{ value: owedAmount }("");
            if (!success) revert NativeTransferFailed();
        }

        /// Checks: Ensure the full amount of native token was provided. Since the buyout amount cannot change
        /// we check for an exact amount.
        if (msgValue != 0) revert InvalidNativeTokenAmount();
    }

    /**
     * @inheritdoc IKeyExchange
     * @dev This function MUST be called by the original key creator before any trading
     * can be facilitated with the associated key ID.
     */
    function setKeyTerms(uint256 keyId, KeyTerms calldata finalTerms) external {
        /// Checks: Ensure that multi-asset vault keys can be traded.
        VaultType vaultType = keys.getKeyConfig(keyId).vaultType;
        if (!multiKeysTradable && vaultType == VaultType.MULTI) revert MultiAssetKeysRestricted();

        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keys.getKeyConfig(keyId).creator) revert CallerNotKeyCreator();

        /// Checks: Ensure restricted users can use the Key Exchange.
        IAccessRegistry.AccessType accessType = accessRegistry.accessType(msg.sender);
        if (accessType == IAccessRegistry.AccessType.RESTRICTED && !allowRestrictedUsers) revert RestrictedUsersBlocked();

        /// Checks: Ensure that a valid market type has been provided.
        if (finalTerms.market == MarketType.UNDEFINED) revert InvalidMarketType();

        /// Checks: Ensure key terms have not already been set.
        if (_keyTerms[keyId].market != MarketType.UNDEFINED) revert KeyTermsDefined();

        if (finalTerms.market == MarketType.FREE) {
            /// Checks: Ensure that buy back and final terms pricing is zero for FREE market.
            if (finalTerms.buyBack != 0 || finalTerms.reserve != 0) revert InvalidFreeMarketTerms();
        } else {
            /// Checks: Ensure that buy back and final terms pricing is non-zero for BUYOUT market.
            if (finalTerms.buyBack == 0 || finalTerms.reserve == 0) revert InvalidBuyOutTerms();

            /// Checks: Ensure the buy back price is greater than the reserve price.
            if (finalTerms.buyBack > finalTerms.reserve) revert BuyBackExceedsReserve();
        }

        /// Set the buy out terms in storage.
        _keyTerms[keyId] = finalTerms;
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function toggleMultiKeyTrading() external onlyRoles(ADMIN_ROLE) {
        multiKeysTradable = !multiKeysTradable;
    }

    function toggleAllowRestrictedUsers() external onlyRoles(ADMIN_ROLE) {
        allowRestrictedUsers = !allowRestrictedUsers;
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function setProtocolFee(uint256 newProtocolFee) external onlyRoles(ADMIN_ROLE) {
        if (newProtocolFee > _BASIS_POINTS) revert FeeExceedsBps();
        protocolFee = newProtocolFee;
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function setFeeReceiver(address newFeeReceiver) external onlyRoles(ADMIN_ROLE) {
        feeReceiver = newFeeReceiver;
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function keyTerms(uint256 keyId) external view returns (KeyTerms memory) {
        return _keyTerms[keyId];
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function incrementNonce() external {
        _incrementNonce();
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function getNonce(address account) external view returns (uint256) {
        return _getNonce(account);
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function hashOrder(Order calldata order) external view returns (bytes32) {
        return _hashOrder(order);
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function hashBid(Bid calldata bid) external view returns (bytes32) {
        return _hashBid(bid);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      VERSION CONTROL                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function nameAndVersion() external pure returns (string memory, string memory) {
        return _domainNameAndVersion();
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
