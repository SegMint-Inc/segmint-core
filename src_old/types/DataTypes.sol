// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * Enum encapsulating the classes of assets that can be stored in a vault/safe.
 */
enum AssetType {
    NONE,
    ERC20,
    ERC721,
    ERC1155
}

/**
 * Namespace for the data types used in {SegMintVaultFactory} and {SegMintVault}.
 */
library Vault {
    
    /**
     * Struct encapsulating the parameters for vault lock and unlock functions.
     * @param assetType Enum defining the class of asset.
     * @param token Contract address of the asset.
     * @param identifier Unique token identifier, only applies to ERC-721/1155 assets.
     * @param amount The amount of asset being held.
     * @dev For ERC-721 tokens, the amount will always be 1.
     */
    struct Asset {
        AssetType assetType;
        address token;
        uint256 identifier;
        uint256 amount;
    }

    /**
     * Enum encapsulating the type of key associated with the vault.
     */
    enum KeyType {
        SINGLE_ASSET,
        MULTI_ASSET
    }
}

/**
 * Namespace for the data type used in {SegMintKYCRegistry}.
 */
library KYCRegistry {
    /**
     * Enum encapsulating the access type related to a specified address.
     * @custom:value BLOCKED: User does not have access.
     * @custom:value RESTRICTED: User has restricted access.
     * @custom:value UNRESTRICTED: User has unrestricted access.
     */
    enum AccessType {
        BLOCKED,
        RESTRICTED,
        UNRESTRICTED
    }
}

/**
 * Namespace for the data type used in {SegMintFactory}.
 */
library Factory {
    /**
     * Struct encapsulating a proposal to upgrade the implementation address.
     * @param newImplementation Newly proposed implementation address.
     * @param deadline Timestamp of when the upgrade proposal can be executed.
     */
    struct UpgradeProposal {
        address newImplementation;
        uint40 deadline;
    }
}

/**
 * Namespace for manging key settings.
 */
library Keys {
    struct Bindings {
        bool binded;
        uint256 keyId;
        uint256 amount;
    }
}

/**
 * Namespace for the data types used in {SegMintKeyExchange}.
 */
library KeyExchange {
    enum Market {
        FREE,
        BUY_OUT,
        CLAW_BACK
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct Pricing {
        uint256 listing;
        uint256 reserve;
        uint256 clawback;
    }

    /**
     * Struct encapsulating information relating to a Maker (Sell) order.
     * @param signer Signer of the order.
     * @param pricing Struct encapsulating the listing, reserve, and clawback prices.
     * @param keyId {SegMintKeys} unique key identifier.
     * @param amount Number of keys to sell.
     * @param paymentToken Token to be used as payment.
     * @param nonce Order nonce, must be unique unless new Maker order is meant to overwrite the existing one.
     * @param startTime Time the order was created.
     * @param endTime Time in which the order becomes void.
     * @param signature Signed order digest.
     */
    struct MakerOrder {
        address signer;
        Pricing pricing;
        uint256 keyId;
        uint256 amount;
        address paymentToken;
        uint256 nonce;
        uint256 startTime;
        uint256 endTime;
        Signature signature;
    }

    struct OrderStatus {
        bool filled;
        bool cancelled;
    }
}
