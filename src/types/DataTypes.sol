// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * Enum encapsulating the classes of assets that can be stored in a vault/safe.
 * @custom:value ERC_20: ERC-20 token.
 * @custom:value ERC_721: ERC-721 token.
 * @custom:value ERC_1155: ERC-1155 token.
 */
enum Class {
    ERC_20,
    ERC_721,
    ERC_1155
}

/**
 * Namespace for the data types used in {SegMintVaultFactory} and {SegMintVault}.
 */
library Vault {
    /**
     * Struct encapsulating the parameters for vault lock and unlock functions.
     * @param class Enum defining the class of asset.
     * @param addr Contract address of the asset.
     * @param tokenId Unique token identifier, only applies to ERC-721/1155 assets.
     * @param amount The amount of asset being held.
     * @dev For ERC-721 tokens, the amount will always be 1.
     */
    struct Asset {
        Class class;
        address addr;
        uint256 tokenId;
        uint256 amount;
    }

    /**
     * Struct encapsulating vault configuration values.
     * @param keyBound Whether or not the vault is bound to keys.
     * @param keyId Unique keys identifier from keys contract.
     * @param keyCount Number of keys associated with the vault.
     */
    struct Config {
        bool keyBound;
        uint64 keyId;
        uint64 keyCount;
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
 * Namespace for the data type used in {SegMintVaultManager}.
 */
library VaultManager {
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
