// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISegMintKeyExchange } from "./interfaces/ISegMintKeyExchange.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { KeyExchange } from "./types/DataTypes.sol";

contract SegMintKeyExchange is ISegMintKeyExchange, Ownable, EIP712 {
    using ECDSA for bytes32;

    /// @dev Basis points used for fee calculation.
    uint256 private constant _FEE_BPS = 10_000;

    ISegMintKeys public keys;

    /// Protocol fee denoted in basis points.
    uint256 public protocolFee;
    address public signer;

    mapping(bytes32 orderHash => KeyExchange.OrderStatus) public orderStatus;
    mapping(address user => uint256 counter) public userNonces;

    constructor(uint256 protocolFee_, address signer_, ISegMintKeys keys_) {
        _initializeOwner(msg.sender);
        protocolFee = protocolFee_;
        signer = signer_;
        keys = keys_;
    }

    /**
     * Function used to cancel an order.
     */
    function cancelOrder(KeyExchange.MakerOrder calldata makerOrder) external {
        /// Checks: Ensure the caller is the signer of the order.
        // if (msg.sender != makerOrder.signer) revert CannotCancelOrder();
    }

    /**
     * Function used to fill an order.
     */
    function fillOrder() external payable { }

    function buyBack() external payable { }

    /**
     * Function used to withdraw protocol fee earnings.
     */
    function withdrawProtocolFees(address token) external onlyOwner { }

    function setProtocolFee(uint256 newProtocolFee) external onlyOwner {
        /// Checks: Ensure that `newProtocolFee` cannot be greater than `_FEE_BPS`.
        protocolFee = newProtocolFee;
    }

    function setSigner(address newSigner) external onlyOwner {
        signer = newSigner;
    }

    /**
     * Overriden function to be used with EIP-712.
     */
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SegMint Key Exchange";
        version = "1.0";
    }
}
