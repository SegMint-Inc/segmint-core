# SegMint Vault & Key Specification

The SegMint Vault & Key ecosystem represents a fractionalized NFT protocol where users secure their assets within a SegMint Vault and create SegMint Keys. These keys take the form of ERC-1155 tokens and represent a semi-fungible counterpart to the locked asset(s). Vaults come in two main types:

- **Single-Asset Vaults**: These are designed for fractionalizing a single locked asset.

- **Multi-Asset Vaults**: These versatile vaults enable the creation of a basket of assets, which may consist of various token types, including fungible and non-fungible assets as well as native token.

## Definitions

*Keys* - An ERC1155 token used to unlock assets contained within vaults. It is worth mentioning that this representation of access control can be circumstantial and will be explained at a later point in this document.

*Single-Asset Vault* - A smart contract that holds a single underlying asset.

*Multi-Asset Vault* - A smart contract that holds multiple underlying assets.

*Key Exchange* - A smart contract used to facilitate atomic trades of Keys utilising the native token and the wrapped native token equivalent. In the context of Ethereum mainnet, this would represent **ETH** and the canonical **WETH** implementation in respective order.

*Wallet* - An EOA account owned by a user of the SegMint platform.

*Order* - Represents a sell intent on the SegMint Key Exchange.

## Protocol Upgradability

The majority of the smart contracts within the Vault & Key ecosystem are immutable with the exception of the `VaultFactory.sol` contract. This contract has been made upgradeable by choice in the chance future vault variations wanted to be provided to the end user.

## Registries

### Signer Registry

The `SignerRegistry.sol` contract is used as a single source of truth for the current signer address. Since ECDSA signatures which are created through a back-end API are required for some components of the ecosystem, I have opted to create a signer registry for this purpose so that in the event the signer needs to be updated, this can be done with a single transaction rather than multiple. It contains one state-changing function which can only be called by the administrator of the contract that updates the current signer address.

### Access Registry

The `AccessRegistry.sol` contract is used to manage KYC verified wallets and the access type associated with them. Since the Vault and Key ecosystem is closed and only KYC'd wallets are allowed to participate and interact with these services, the Access Registry can be queried to view the access type associated with a given wallet.

In order to successfully call the `initAccessType` function, a user must be KYC'd with the SegMint platform. If this is the case, our backend will provide a signature and their associated access type to the end user which they can use as the parameters for this function.

Once a wallets access type has been defined, it can only ever be modified through an administrator. The enum values (`AccessType`) that can be associated with a wallet address are as follows:

| Enum Value | Description |
|------------|-------------|
| **BLOCKED** | The wallet doesn't have access to Vault & Key related services. |
| **RESTRICTED** | The wallet address is associated a US KYC'd user. |
| **UNRESTRICTED** | The wallet address is associated with a non-US KYC'd user. |

**Considerations**: After discussion with the team, this seemed to be a more suitable approach rather than explicitly stating the geolocation of a wallet address. We are open to hearing suggestions on how this can be made less "doxxy" per se.

## Factories

### Vault Factory

The `VaultFactory.sol` contract is used to create both single-asset and multi-asset vaults. This contract has been made upgradeable due to the point that can be found [here](#protocol-upgradability). It is worth mentioning that whilst this contract is upgradable, a strict 5 day timelock has been implemented via the `UpgradeHandler.sol` smart contract. This is to ensure that in the event a SegMint administrator is compromised and the bad actor wants to brick the Factory with a bad implementation, the team has 5 days notice to remedy the situation.

In order to keep the creation of these vaults gas efficient, I have opted to use clones for the creation of each vault type. The implementation addresses for both vault types will be provided to the ERC1967 proxy via the constructor upon deployment. The terms `maVault` and `saVault` refer to the multi-asset and single-asset vault implementation addresses respectively. To prevent storing the addressess for each vault type of each user in storage, I have also opted to utilise a nonce system that is similar to the way UniSwap V2 handles pair prediction.

The address of the caller which is derived from `msg.sender` and the nonce are hashed together to create a salt that is used in conjunction with `CREATE2` to create vaults. A simply function `_predictDeployments()` is used to derive the addresses of al vaults created by each user.

## Vaults

### Single Asset Vault (SAVault)

The `SAVault.sol` contract contains the implementation logic for single-asset vaults.

When a single-asset vault is created, the underlying asset which can only be an ERC721 or ERC1155 token/s (for regulatory reasons) is transferred to the newly created vault and the specified number of keys are minted to the user, this entire process is atomic. Since key creation is atomic, single-asset vaults have no concept of a vault owner and instead use the associated key's ID supply holder for access control.

When the underlying asset is unlocked, all keys of the ID associated with the vault will be burnt and the underlying asset will be transferred to the caller. From here, the vault is essentially bricked and cannot be reused.

### Multi Asset Vaults (MAVault)

The `MAVault.sol` contract contains the implementation logic for multi-asset vaults.

When a multi-asset vault is created, the user will specify the number of keys to associate with the vault and will subsequently receive the  minted keys after their transaction has been included into a block.

After vault creation, users will be prompted via the platform to transfer the desired basket of assets into the vault. Our back-end infrastructure will acknowledge these transfers and update the platform website accordingly to reflect the underlying assets associated with the keys.

It is worth mentioning that once assets have been deposited into the vault, the creator should not be able to withdraw these assets without burning the entire supply of keys associated with it.

The nature in which assets can be unlocked relates strictly to the `claimOwnership` function. Calling this function whilst holding the entire supply of keys will subsequently burn the keys and transfer ownership of the vault to the caller. Since assets can only be withdrawn when no key ID is associated with the vault (`boundKeyId` is zero), this will enable the new owner to withdraw the assets within the vault on their own terms.

## Key Services

### Keys

The `Keys.sol` contract contains all the logic associated with Keys. Keys should only be mintable by vaults and only a single key ID should be associated with a given vault at any given time. The function `isRegistered` which can only be called by the Vault Factory provides access control for vaults to call the `createKeys` function. For single-asset vaults, this is done atomically in the same transaction that the vault is created. For multi-asset vaults, the owner can call this function directly through the vault when they have finished depositing assets.

One notable feature of keys is that they can be lended out to other KYC'd users of the platform for a duration of time. E.g. Alice has a multi-asset vault with 10 keys bounded to it and wants to lend 1 key to Bob. Alice lends Bob 1 key for 3 days. Whilst Bob is in possession of this lended key, he should never be able to sell it or transfer it to another user, this key should be soulbound.

However, if Bob purchases 1 key of the same key ID (whereby he now holds two), he should be able to freely sell 1 key whilst in possession of the lended key. Whilst the lended key is not transferrable, it can be returned to Alice by either a direct transfer using `safeTransferFrom` or by Alice calling the `reclaimKey` function after the lending period has lapsed.

It is be design that only one lend can be active for a lendee for a given key ID at any point in time. E.g. If Alice lends Bob key ID #1, Charles cannot lend out the same key ID to Bob. However, Charles can lend Bob the desired amount of keys for key ID #2. Once Bob has returned the lended keys to Alice, Charles can then lend key #1 to Bob.

Due to regulatory compliance, SegMint has opted to implement the freezing of Keys to comply with possible requests from authoritative bodies. This means that in the event Eve is suspected to be a bad actor who has **created** keys, an administrator can freeze the respective key ID and subsequently, the underlying assets within her associated vault.

Subsequently, due to the requirements of SegMints buyback and reserve purchase requests, the `isApprovedForAll` function has been overridden to allow for the Key Exchange contract to facilitate these actions. This will be explained below.

### Key Exchange

The `KeyExchange.sol` contract is used to facilitate the trading of Keys. An important point to note is that this contract inherits the `OperatorFilter.sol` contract which will be used to prohibit trading of Keys outside of the Key Exchange. Whilst standard transfers to other KYC'd users are fine, no trading should be able to take place on OpenSea or any other marketplaces besides the SegMint Key Exchange.

When it comes to selling keys via the Key Exchange, sellers of a given key ID will sign orders off-chain which will be made viewable via the platform website for buyers to act upon. If a seller wishes to increase the listing price of a given order, they will be required to send a transaction that acknowledges the previous order hash to be void and unactionable.

If the inverse scenario occurs where a seller wants to reduce the listing price of a given order, they will *not* require a stateful transaction and instead the higher priced listing will be removed from the website. However, users will have the option to cancel this listing regardless via an interface of the SegMint platform.

When it comes to bidding on keys via the Key Exchange, bidders are able to place bids using the wrapped native token which can be acted upon by parties that hold the respective asset in the desired quantity. Since keys are ERC1155, I decided to take a similar approach to most marketplaces where a bid is considered on the overall key ID rather than a specified listing.

#### Important Notes Regarding Trading

Before any trading can take place, the creator of the key (the user who binded them to a vault) must define the associated keys terms. Terms can be defined under two market conditions, and relate the the `IKeyExchange.MarketType` enum, these are as follows:

| Enum Value | Description |
|------------|-------------|
| **UNDEFINED** | No key terms have been set. |
| **FREE** | Free market, no buyout or reserve functionality can be actioned. |
| **BUYOUT** | Buyout market, key creator can perform buyouts and users can execute reserve purchases. |

**It is important to note that once key terms have been defined for a collection, they cannot be modified.**

#### Free Market

If a user has chosen to sell their keys on the free market, they are unable to perform a buy out or reserve purchase for the desired keys. For this reason, the associated `IKeyExchange.KeyTerms` struct **MUST** have a respective `buyBack` and `reserve` value of zero.

It is acknowledged that an asset can be lost forever in the event a malicious key holder chooses to never sell a listed key. The user will always be prompted to list their keys via the buy out market on the SegMint platform, however this option is available regardless.

#### Buy Out Market

If a user has chosen the buy out market, they will be required to define a buy back price and a reserve price. The difference between these two pricing models is that only the creator can execute a buy back which essentially takes a specified number of keys from each of the holders provided and pays them the respective amount owed.

E.g. Alice requires 10 keys to unlock the asset from her vault but only holds 7 of them, if she has set a buy back price of 0.1 Ether, she can pay Bob who holds 3 keys 0.3 Ether and forcefully take them back. It is for this reason, the Key Exchange address always returns as approved for all within the `Keys.sol` contract.

**It is worth mentioning that when a buy back occurs, the entire supply of keys must be bought back at once.** This is to ensure that no matter what, the underlying asset can be reclaimed at a cost. Buy back prices should always be less than or equal to the reserve price.

Users that did not create the key are provided with similar functionality related to reserve pricing model, however they do not need to conduct an entire supply purchase when acquiring keys through the reserve pricing method

E.g. Bob holds 3 keys and Charlie wishes to purchase 1. Charlie can forcefully take 1 key from Bob by paying the reserve price. If the reserve price for the given key ID is 1 Ether, Bob will receive 1 Ether in exchange for 1 key.

The above mentioned scenario is intended as described by the business logic. The information relating to a key will always be displayed on the SegMint platform to keep users informed so that they can reason about the purchase of certain key IDs.

#### Accessibility

With reference to the previously mentioned access types, there are a couple of caveats to note when it comes to trading keys via the Key Exchange. On deployment and until regulatory clarity is achieved, keys associated with multi-asset vaults **SHOULD NOT** be tradable. However, the `toggleMultiKeyTrading` function allows the administrator to allow for this at a later point in the future.

Due to regulatory reasons, users with the `RESTRICTED` access type should not be able to create/execute orders/bids. However, the `toggleAllowRestrictedUsers` function allows the administrator to allow for this at a later point in the future.

#### Fees

The Key Exchange should take a 5.00% protocol fee (subject to change) on all trades that are facilitated through the Key Exchange. Fees are not taken when users perform a buy back and/or reserve purchase.

**Considerations**:

- Since the entire supply of keys must be purchased in a single transaction, it is acknowledged that this may be heavily gas intensive. For this reason, we have decided to cap the maximum number of keys that can be created by a vault to 100, this value is defined within the `Keys.sol` contract.
- In addition to the point above, we have also concluded that DoS attacks *should not* be feasible, as keys can only be transferred to KYC'd addresses whereby the appropriate measures will be taken off-chain to ensure that the account registering with the KYC Registry is not a smart contract.
  