// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/security/ReentrancyGuard.sol";
import { TypeHasher } from "./handlers/TypeHasher.sol";
import { NonceManager } from "./managers/NonceManager.sol";
import { IKeyExchange } from "./interfaces/IKeyExchange.sol";
import { IAccessRegistry } from "./interfaces/IAccessRegistry.sol";
import { IMAVault } from "./interfaces/IMAVault.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title KeyExchange
 * @notice Facilitates trading of Keys.
 */

contract KeyExchange is IKeyExchange, OwnableRoles, NonceManager, TypeHasher, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @dev Total basis points used for fee calculation.
    uint256 private constant _BASIS_POINTS = 10_000;

    /// @dev Total gas to forward on royalty payments.
    uint256 private constant _ROYALTY_GAS_STIPEND = 2_300;

    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    /// @dev Wrapped native token contract.
    IERC20 public immutable WETH;
    IKeys public immutable keys;
    IAccessRegistry public immutable accessRegistry;

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
        if (admin_ == address(0)) revert ZeroAddressInvalid();
        if (feeReceiver_ == address(0)) revert ZeroAddressInvalid();
        if (weth_ == address(0)) revert ZeroAddressInvalid();
        if (address(keys_) == address(0)) revert ZeroAddressInvalid();
        if (address(accessRegistry_) == address(0)) revert ZeroAddressInvalid();

        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        WETH = IERC20(weth_);
        feeReceiver = feeReceiver_;

        keys = keys_;
        accessRegistry = accessRegistry_;
    }

    modifier checkCaller() {
        _checkAccess(msg.sender);
        _;
    }

    /**
     * @inheritdoc IKeyExchange
     * @dev `msg.sender` in this context is a user wishing to fill an order, a buyer.
     */
    function executeOrders(OrderParams[] calldata orders) external payable checkCaller nonReentrant {
        /// Checks: Ensure a non-zero amount of orders have been specified.
        if (orders.length == 0) revert ZeroLengthArray();

        /// Push initial `msg.value` to the stack.
        uint256 msgValue = msg.value;

        /// Tracks the total fees to be paid for all orders.
        uint256 totalFees = 0;

        for (uint256 i = 0; i < orders.length;) {
            /// Cache respective order parameters.
            Order calldata order = orders[i].order;
            bytes calldata signature = orders[i].signature;

            /// Checks: Ensure the order maker has valid access to the Key Exchange.
            _checkAccess(order.maker);

            /// Checks: Ensure that the key terms have been defined for the associated key ID.
            MarketType keyMarket = _keyTerms[order.keyId].market;
            if (keyMarket == MarketType.UNDEFINED || keyMarket == MarketType.INACTIVE) revert InvalidKeyMarket();

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

            /// Caclulate total payable royalties.
            uint256 payableRoyalties = order.royalties.length == 0 ? 0 : _calculateRoyaltyPayment(order.royalties);

            /// Calculate the protocol fee and subtract from the order price.
            uint256 calculatedFee = order.price * order.protocolFee / _BASIS_POINTS;
            uint256 makerEarnings = order.price - calculatedFee - payableRoyalties;

            /// Update the total amount of native token to pay the protocol.
            totalFees += calculatedFee;

            /// Pay the maker earnings, forward a sufficient amount of gas.
            (bool success,) = order.maker.call{ value: makerEarnings }("");
            if (!success) revert NativeTransferFailed();

            /// Pay the royalties if any are due.
            if (payableRoyalties != 0) {
                _payRoyaltiesWithNativeToken(order.royalties);
            }

            /// Checks: Ensure a sufficient amount of native token has been provided.
            if (order.price > msgValue) revert InvalidNativeTokenAmount();
            msgValue -= order.price;

            /// Emit event after the order has been completely filled.
            emit OrderFilled(orderHash);

            unchecked { i++; }
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
     * @dev `msg.sender` in this context is a user wishing to accept a bid, a seller.
     */
    function executeBids(BidParams[] calldata bidParams) external checkCaller nonReentrant {
        /// Checks: Ensure a non zero amount of bids have been provided.
        if (bidParams.length == 0) revert ZeroLengthArray();

        for (uint256 i = 0; i < bidParams.length;) {
            /// Cache respective bid parameters.
            Bid calldata bid = bidParams[i].bid;
            bytes calldata signature = bidParams[i].signature;

            /// Checks: Ensure the bid maker has valid access to the Key Exchange.
            _checkAccess(bid.maker);

            /// Checks: Ensure that key terms have been defined for the key identifier.
            MarketType keyMarket = _keyTerms[bid.keyId].market;
            if (keyMarket == MarketType.UNDEFINED || keyMarket == MarketType.INACTIVE) revert InvalidKeyMarket();

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

            /// Caclulate total payable royalties.
            uint256 payableRoyalties = bid.royalties.length == 0 ? 0 : _calculateRoyaltyPayment(bid.royalties);

            /// Calculate protocol fee.
            uint256 calculatedFee = bid.price * bid.protocolFee / _BASIS_POINTS;
            uint256 takerEarnings = bid.price - calculatedFee - payableRoyalties;

            /// Pay protocol fee.
            WETH.safeTransferFrom(bid.maker, feeReceiver, calculatedFee);

            /// Pay the royalties if any are due.
            if (payableRoyalties != 0) {
                for (uint256 j = 0; j < bid.royalties.length; j++) {
                    IKeyExchange.Royalties calldata royaltyInfo = bid.royalties[j];
                    if (royaltyInfo.receiver == address(0)) revert ZeroAddressInvalid();
                    WETH.safeTransferFrom(bid.maker, royaltyInfo.receiver, royaltyInfo.fee);
                }
            }

            /// Pay bid maker.
            WETH.safeTransferFrom(bid.maker, msg.sender, takerEarnings);

            /// Emit event to acknowledge the bid has been filled.
            emit BidFilled(bidHash);

            unchecked { i++; }
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function cancelOrders(Order[] calldata orders) external {
        /// Checks: Ensure a non-zero amount of orders have been specified.
        if (orders.length == 0) revert ZeroLengthArray();

        /// Iterate through each order.
        for (uint256 i = 0; i < orders.length;) {
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

            unchecked { i++; }
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function cancelBids(Bid[] calldata bids) external {
        /// Checks: Ensure a non-zero amount of bids have been provided.
        if (bids.length == 0) revert ZeroLengthArray();

        /// Iterate through each bid.
        for (uint256 i = 0; i < bids.length;) {
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

            unchecked { i++; }
        }
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function executeBuyBack(uint256 keyId, address[] calldata holders) external payable nonReentrant {
        /// Cache key configuration in memory.
        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);

        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keyConfig.creator) revert CallerNotKeyCreator();

        /// Checks: Ensure a valid number of holders or amounts have been provided.
        if (holders.length == 0) revert ZeroLengthArray();

        /// Copy key terms in to memory.
        KeyTerms memory terms = _keyTerms[keyId];

        /// Checks: Ensure buy out terms have been set.
        if (terms.market != MarketType.BUYOUT) revert KeyNotBuyOutMarket();

        /// Reclaim all the keys from the provided holders.
        _reclaimKeys({ keyId: keyId, keyPrice: terms.buyBack, holders: holders });

        /// Checks: Ensure all keys were successfully transferred to the holder.
        if (IERC1155(address(keys)).balanceOf(msg.sender, keyId) != keyConfig.supply) revert BuyBackFailed();

        /// Set key terms to inactive to prevent further trading.
        _keyTerms[keyId] = KeyTerms({ market: MarketType.INACTIVE, buyBack: 0, reserve: 0 });

        emit BuyOutExecuted({ caller: msg.sender, keyId: keyId });
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function buyAtReserve(uint256 keyId, address[] calldata holders) external payable checkCaller nonReentrant {
        /// Checks: Ensure a valid number of holders have been provided.
        if (holders.length == 0) revert ZeroLengthArray();

        /// Copy key terms in to memory.
        KeyTerms memory terms = _keyTerms[keyId];

        /// Checks: Ensure buy out terms have been set.
        if (terms.market != MarketType.BUYOUT) revert KeyNotBuyOutMarket();

        /// Reclaim all the keys from the provided holders.
        _reclaimKeys({ keyId: keyId, keyPrice: terms.reserve, holders: holders });

        /// Checks: Ensure all keys were successfully transferred to the holder.
        uint256 maxSupply = keys.getKeyConfig(keyId).supply;
        if (IERC1155(address(keys)).balanceOf(msg.sender, keyId) != maxSupply) revert BuyBackFailed();

        /// Set key terms to inactive to prevent further trading.
        _keyTerms[keyId] = KeyTerms({ market: MarketType.INACTIVE, buyBack: 0, reserve: 0 });

        emit ReserveBuyOut({ caller: msg.sender, keyId: keyId });
    }

    /**
     * @inheritdoc IKeyExchange
     * @dev This function MUST be called by the original key creator before any trading
     * can be facilitated with the associated key ID.
     */
    function setKeyTerms(uint256 keyId, KeyTerms calldata finalTerms) external checkCaller {
        /// Checks: Ensure that multi-asset vault keys can be traded.
        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        if (!multiKeysTradable && keyConfig.vaultType == VaultType.MULTI) revert MultiAssetKeysRestricted();

        /// Checks: Ensure the caller is the original creator of the keys.
        if (msg.sender != keyConfig.creator) revert CallerNotKeyCreator();

        /// Checks: Ensure that a valid market type has been provided.
        if (finalTerms.market == MarketType.UNDEFINED || finalTerms.market == MarketType.INACTIVE) {
            revert InvalidMarketType();
        }

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

        emit KeyTermsSet({ keyId: keyId, keyTerms: finalTerms });
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function toggleMultiKeyTrading() external onlyRoles(ADMIN_ROLE) {
        multiKeysTradable = !multiKeysTradable;
        emit MultiKeyTradingUpdated({ newStatus: multiKeysTradable });
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function toggleAllowRestrictedUsers() external onlyRoles(ADMIN_ROLE) {
        allowRestrictedUsers = !allowRestrictedUsers;
        emit RestrictedUserAccessUpdated({ newStatus: allowRestrictedUsers });
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function setProtocolFee(uint256 newProtocolFee) external onlyRoles(ADMIN_ROLE) {
        if (newProtocolFee > _BASIS_POINTS) revert FeeExceedsBps();
        uint256 oldProtocolFee = protocolFee;
        protocolFee = newProtocolFee;
        emit ProtocolFeeUpdated({ oldFee: oldProtocolFee, newFee: newProtocolFee });
    }

    /**
     * @inheritdoc IKeyExchange
     */
    function setFeeReceiver(address newFeeReceiver) external onlyRoles(ADMIN_ROLE) {
        if (newFeeReceiver == address(0)) revert ZeroAddressInvalid();
        address oldFeeReceiver = feeReceiver;
        feeReceiver = newFeeReceiver;
        emit FeeReceiverUpdated({ oldFeeReceiver: oldFeeReceiver, newFeeReceiver: newFeeReceiver });
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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to determine if the caller has valid access to use the Key Exchange. It shouldn't matter if the
     * caller has the `BLOCKED` access type as all key transfers will revert if so.
     */
    function _checkAccess(address account) internal view {
        IAccessRegistry.AccessType accessType = accessRegistry.accessType(account);
        if (accessType == IAccessRegistry.AccessType.RESTRICTED && !allowRestrictedUsers) revert Restricted();
    }

    /**
     * Function used to reclaim keys from the provided holders and distribute the calculated amount of earnings.
     */
    function _reclaimKeys(uint256 keyId, uint256 keyPrice, address[] calldata holders) internal {
        /// Push original `msg.value` on to the stack.
        uint256 msgValue = msg.value;

        for (uint256 i = 0; i < holders.length;) {
            address holder = holders[i];
            uint256 keyBalance = IERC1155(address(keys)).balanceOf(holder, keyId);
            if (keyBalance == 0) revert NoKeysHeld();

            /// Calculate the earnings to be distributed.
            uint256 earnings = keyPrice * keyBalance;
            if (earnings > msgValue) revert InvalidNativeTokenAmount();
            msgValue -= earnings;

            /// Check if the keys held by the holder are lended and distribute earnings accordingly.
            IKeys.LendingTerms memory lendingTerms = keys.activeLends(holder, keyId);

            if (lendingTerms.amount == 0) {
                (bool success,) = holder.call{ value: earnings }("");
                if (!success) revert NativeTransferFailed();
            } else {
                /// Clear the associated lend to allow for key transfers after earnings distribution. Doing so
                /// avoids the transaction reverting with `CannotTransferLendedKeys`.
                keys.clearLendingTerms({ lendee: holder, keyId: keyId });

                /// If all keys held by the holder are lended, distribute the earnings to the original lender.
                if (lendingTerms.amount == keyBalance) {
                    (bool success,) = lendingTerms.lender.call{ value: earnings }("");
                    if (!success) revert NativeTransferFailed();

                    /// Otherwise, distribute earnings to both the lender and holder.
                } else {
                    uint256 holderEarnings = keyPrice * (keyBalance - lendingTerms.amount);

                    (bool success,) = holder.call{ value: holderEarnings }("");
                    if (!success) revert NativeTransferFailed();

                    (success,) = lendingTerms.lender.call{ value: earnings - holderEarnings }("");
                    if (!success) revert NativeTransferFailed();
                }
            }

            /// Transfer keys to the caller.
            IERC1155(address(keys)).safeTransferFrom(holder, msg.sender, keyId, keyBalance, "");

            unchecked { i++; }
        }

        /// Refund any remaining native token to the caller.
        if (msgValue > 0) {
            (bool success,) = msg.sender.call{ value: msgValue }("");
            if (!success) revert NativeTransferFailed();
        }
    }

    /**
     * Function used to calculate the royalty payments to each of the respective parties.
     */
    function _calculateRoyaltyPayment(IKeyExchange.Royalties[] calldata royalties) internal pure returns (uint256) {
        uint256 royaltySum = 0;
        for (uint256 i = 0; i < royalties.length;) {
            royaltySum += royalties[i].fee;
            unchecked { i++; }
        }
        return royaltySum;
    }

    /**
     * Function used to pay royalties to the respective parties.
     */
    function _payRoyaltiesWithNativeToken(IKeyExchange.Royalties[] calldata royalties) internal {
        for (uint256 i = 0; i < royalties.length;) {
            IKeyExchange.Royalties calldata royaltyInfo = royalties[i];
            if (royaltyInfo.receiver == address(0)) revert ZeroAddressInvalid();

            /// Wraps the royalty fee to WETH if the native call fails.
            (bool success,) = royaltyInfo.receiver.call{ gas: _ROYALTY_GAS_STIPEND, value: royaltyInfo.fee }("");
            if (!success) {
                IWETH(address(WETH)).deposit{ value: royaltyInfo.fee };
                WETH.safeTransferFrom({ from: address(this), to: royaltyInfo.receiver, value: royaltyInfo.fee });
            }

            unchecked { i++; }
        }
    }
}

interface IWETH {
    function deposit() external payable;
}