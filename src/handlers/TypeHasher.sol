// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

import { EIP712 } from "@solady/src/utils/EIP712.sol";
import { IKeyExchange } from "../interfaces/IKeyExchange.sol";

/**
 * @title TypeHasher
 * @notice Used to derive the EIP712 hash associated with Order/Bid types for {KeyExchange}.
 */
abstract contract TypeHasher is EIP712 {
    /// Royalties(address receiver,uint256 fee)
    bytes32 private constant _ROYALTIES_TYPEHASH = 0x2f5057decee872280b232f42dc21db20fd2f34148dcb1f26e39248197261978e;

    /// Order(uint256 price,address maker,address taker,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime,uint256 protocolFee,Royalties[] royalties)Royalties(address receiver,uint256 fee)
    bytes32 private constant _ORDER_TYPEHASH = 0x181555209a4040dc9b2401944efa8ca3b593b5fc3981fa4b4c4996bcea6c727f;

    /// Bid(address maker,uint256 price,uint256 keyId,uint256 amount,uint256 nonce,uint256 startTime,uint256 endTime,uint256 protocolFee,Royalties[] royalties)Royalties(address receiver,uint256 fee)
    bytes32 private constant _BID_TYPEHASH = 0x06c6c02a5759b468552d3e3ce52a9399e1ab78fb9194e4e0fed6b8f57aa1afee;

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
            order.endTime,
            order.protocolFee,
            _hashRoyalties(order.royalties)
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
            bid.endTime,
            bid.protocolFee,
            _hashRoyalties(bid.royalties)
        )));
    }

    /**
     * Function used to return the EIP712 hash of a royalty payment.
     */
    function _hashRoyalties(IKeyExchange.Royalties[] calldata royalties) internal pure returns (bytes32) {
        bytes32[] memory encodedRoyalties = new bytes32[](royalties.length);
        for (uint256 i = 0; i < royalties.length; i++) {
            IKeyExchange.Royalties memory royalty = royalties[i];
            encodedRoyalties[i] = keccak256(abi.encode(
                _ROYALTIES_TYPEHASH,
                royalty.receiver,
                royalty.fee
            ));
        }
        return keccak256(abi.encodePacked(encodedRoyalties));
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
