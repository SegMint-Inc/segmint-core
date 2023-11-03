// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { EIP712 } from "solady/src/utils/EIP712.sol";
import { IKeyExchange } from "../interfaces/IKeyExchange.sol";

/**
 * @title TypeHasher
 * @notice Used to derive the EIP712 hash associated with Order/Bid types for {KeyExchange}.
 */
abstract contract TypeHasher is EIP712 {
    /// Order(uint256 price,address maker,address taker,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime)
    bytes32 private constant _ORDER_TYPEHASH = 0x9a3b6761b926f38baa0938ef9c869311aed6761ec5857a410ad87bd983171278;

    /// Bid(address maker,uint256 price,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime)
    bytes32 private constant _BID_TYPEHASH = 0xb69b3ab835bfc035f012e000cfad373eef5aac883f78fd75ceb85dcfb109f3c7;

    /**
     * Function used to return the EIP712 hash of a order.
     */
    function _hashOrder(IKeyExchange.Order calldata order) internal view returns (bytes32) {
        /// forgefmt: disable-next-item
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

    /**
     * Function used to return the EIP712 hash of a bid.
     */
    function _hashBid(IKeyExchange.Bid calldata bid) internal view returns (bytes32) {
        /// forgefmt: disable-next-item
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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EIP712                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * As required in Solady EIP712 documentation.
     */
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory name, string memory version)
    { }
}
