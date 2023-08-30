// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * Enum encapsulating the types of asset classes that can be vaulted.
 */
enum AssetClass {
    NONE,
    ERC20,
    ERC721,
    ERC1155
}

/**
 * Struct encapsulating the parameters for a vaulted asset.
 * @param class Enum defining the class of the asset.
 * @param token Contract address of the asset.
 * @param identifier Unique token identifier.
 * @param amount The amount of the asset being locked.
 * @dev For ERC721 tokens, the `amount` should always be 1.
 */
struct Asset {
    AssetClass class;
    address token;
    uint256 identifier;
    uint256 amount;
}

/**
 * Enum encapsulating the type of vault keys are associated with.
 */
enum VaultType {
    NONE,
    SINGLE,
    MULTI
}

struct KeyConfig {
    address creator;
    VaultType vaultType;
    bool isFrozen;
    bool isBurned;
    uint8 supply;
}