# SegMint Vault & Key Specification

The SegMint Vault & Key ecosystem represents a fractionalized NFT protocol where users secure their assets within a SegMint Vault and create SegMint Keys. These keys take the form of ERC-1155 tokens and represent a semi-fungible counterpart to the locked asset(s). Vaults come in two main types:

- **Single-Asset Vaults**: These are designed for fractionalizing a single locked asset which adheres to either the ERC721 or ERC1155 standard.

- **Multi-Asset Vaults**: These versatile vaults enable the creation of a basket of assets, which may consist of various token types, including fungible and non-fungible assets as well as native token. Multi-asset vaults allow for the deposit of native token and tokens that adhere to the ERC20, ERC721 and ERC1155 standards.

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

The `AccessRegistry.sol` contract is used to manage KYC verified wallets and the access type associated with them. Since the Vault and Key ecosystem is closed and only KYC'd wallets are allowed to participate and interact with the services we provide, the Access Registry can be queried to view the access type associated with a given wallet.

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

When a single-asset vault is created, the underlying asset which can only be an ERC721 or ERC1155 token/s (for regulatory reasons) is transferred to the newly created vault and the specified number of keys are minted to the user, this entire process is atomic. Since key creation is atomic, single-asset vaults have no concept of a vault owner and instead use the associated vaults key's ID supply holder for access control.

When the underlying asset is unlocked, all keys of the ID associated with the vault will be burnt and the underlying asset will be transferred to the caller. From here, the vault is essentially bricked and cannot be reused.

### Multi Asset Vaults (MAVault)

The `MAVault.sol` contract contains the implementation logic for multi-asset vaults.

When a multi-asset vault is created, the user will specify the number of keys to associate with the vault and will subsequently receive the  minted keys after their transaction has been included into a block.

After vault creation, users will be prompted via the platform to transfer the desired basket of assets into the vault. Our back-end infrastructure will acknowledge these transfers and update the platform website accordingly to reflect the underlying assets associated with the keys.

It is worth mentioning that once assets have been deposited into the vault, the creator is not able to withdraw these assets without burning the entire supply of keys associated with it.

The nature in which assets can be unlocked relates strictly to the `claimOwnership` function. Calling this function whilst holding the entire supply of keys will subsequently burn the keys and transfer ownership of the vault to the caller. Since assets can only be withdrawn when no key ID is associated with the vault (`boundKeyId` is zero), this will enable the new owner to withdraw the assets within the vault on their own terms.

## Asset Delegation

Vaults created through the Vault Factory integrate with the [delegate.xyz](https://delegate.xyz/) Delegate V2 Registry found at this [address](https://etherscan.io/address/0x00000000000000447e69651d841bd8d104bed493#code). This integration provides vault owners with flexibility to delegate rights of the underlying assets in a variety of different use cases.

In the context of a single-asset vault, only the original vault creator may delegate rights to the underlying asset. Creators will be able to see their active delegations for a vault via the SegMint platform in order to manage these delegations clearly in a way that makes sense. Such a use case might be that Alice is the creator a vault where she has locked a token that has an upcoming mint where token owners can claim 1 free mint and the minting contract itself integrates with delegate.xyz. Since she doesn't want to miss out, she can delegate rights of the underlying token to her hot wallet so that she can participate in the mint without reclaiming all the keys and unlocking the asset.

For multi-asset vaults, only the Vault owner can modify delegation rights. Since asset unlocking for multi-asset vaults is non-atomic, once a user has acquired all the keys associated with a multi-asset vault and claimed ownership, they have the freedom to clear all existing delegations since they may choose to keep the assets in the vault for some period of time. Asset delegation within the context of multi-asset vaults is unique as it allows a vault owner to delegate rights of specific tokens to specific users, meaning that in the example above (but in a multi-asset vault context), Alice could delegate rights for two seperate tokens to two seperate users.

Note: Clearing delegation rights isn't necessarily an issue in the context of single-asset vaults as the underlying asset itself is atomically unlocked when the keys to access a vault have been burned.

## Key Services

### Keys

The `Keys.sol` contract contains all the logic associated with Keys. Keys should only be mintable by vaults and only a single key ID should be associated with a given vault at any given time. The function `isRegistered` which can only be called by the Vault Factory provides access control for vaults to call the `createKeys` function.

One notable feature of keys is that they can be lended out to other KYC'd users of the platform for a duration of time. E.g. Alice has a multi-asset vault with 10 keys bounded to it and wants to lend 1 key to Bob. Alice lends Bob 1 key for 3 days. Whilst Bob is in possession of this lended key, he should never be able to sell it or transfer it to another user, this key should be soulbound.

However, if Bob purchases 1 key of the same key ID (whereby he now holds two), he should be able to freely sell 1 key whilst in possession of the lended key. Whilst the lended key is not transferrable, it can be returned to Alice by either a direct transfer using `safeTransferFrom` or by Alice calling the `reclaimKey` function after the lending period has lapsed. Additionally, if a Vault creator calls `executeBuyOut` or a general user calls `buyAtReserve`, the keys will be transferred to the caller and the original lender will receive the earnings. This functionality has been added to allow for asset recovery even in the event of some of the Vault keys being lended out.

It is be design that only one lend can be active for a lendee for a given key ID at any point in time. E.g. If Alice lends Bob key ID #1, Charles cannot lend out the same key ID to Bob. However, Charles can lend Bob the desired amount of keys for key ID #2. Once Bob has returned the lended keys to Alice, Charles can then lend key #1 to Bob.

Due to regulatory compliance, SegMint has opted to implement the freezing of Keys to comply with possible requests from authoritative bodies. This means that in the event Eve is suspected to be a bad actor who has **created** keys, an administrator can freeze the respective key ID and subsequently, the underlying assets within her associated vault.

Subsequently, due to the requirements of SegMints buyback and reserve purchase requests, the `isApprovedForAll` function has been overridden to allow for the Key Exchange contract to facilitate these actions by default. This will be explained below.

#### Regarding Key Lending

As previously mentioned, Key Lending enables the capability for SegMint keys to be lended out to users within the SegMint protocol. An example of this is as follows:

1. Alice is an artist that creates a single-asset Vault with 10 keys, the Vault itself contains a 1/1 artwork.
2. Alice lends Bob, a close friend of hers, 1 key for 30 days and sells the remaining 9 keys via the SegMint platform.
3. Within the next 30 days, Alice wants to airdrop her new artwork which is a collection of 10 pieces to all her key holders, each key holder receiving 1 piece.
4. As Bob is in possession of the lended key, he is eligable for the airdrop.
5. After the airdrop has been conducted and the lending period has elapsed, Alice can reclaim this key and choose to either sell it or keep it for her own personal holdings.

Keys can be reclaimed in THREE different ways:

1. Bob can simply transfer the key back to Alice after the airdrop has concluded, this will clear his lending terms.
2. Alice can call the `reclaimKeys` function provided on the SegMint UI after the 30 day lending period has lapsed.
3. Either Alice or a user interested in her 1/1 artwork can call the `executeBuyOut` (for Alice) or the `buyAtReserve` (for users) given that they pay the appropriate prices and that the key terms for the specified key ID allow it.

**NOTE**: Key terms and what they mean are described in detail below.

### Key Exchange

The `KeyExchange.sol` contract is used to facilitate the trading of Keys. An important point to note is that this contract inherits the `OperatorFilter.sol` contract which will be used to prohibit trading of Keys outside of the Key Exchange. Whilst standard transfers to other KYC'd users are fine, no trading should be able to take place on OpenSea or any other marketplaces besides the SegMint Key Exchange.

When it comes to selling keys via the Key Exchange, sellers of a given key ID will sign orders off-chain which will be made viewable via the platform website for buyers to act upon. If a seller wishes to increase the listing price of a given order, they will be required to send a transaction that acknowledges the previous order hash to be void and unactionable.

If the inverse scenario occurs where a seller wants to reduce the listing price of a given order, they will *not* require a stateful transaction and instead the higher priced listing will be removed from the website. However, users will have the option to cancel this listing regardless via an interface of the SegMint platform.

When it comes to bidding on keys via the Key Exchange, bidders are able to place bids using the wrapped native token which can be acted upon by parties that hold the respective asset in the desired quantity. Since keys are ERC1155, I decided to take a similar approach to most marketplaces where a bid is considered on the overall key ID rather than a specified listing.

#### Important Notes Regarding Trading

Before any trading can take place, the creator of the key (the user who created the vault unto which the keys are binded to) must define the associated keys terms. Terms can be defined under two market conditions, and relate the the `IKeyExchange.MarketType` enum, these are as follows:

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

E.g. Alice requires 10 keys to unlock the asset from her vault but only holds 7 of them, if she has set a buy back price of 0.1 Ether, she can pay Bob who holds 3 keys 0.3 Ether and recover the remaining 3 keys through the `executeBuyOut` function. It is for this reason, the Key Exchange address always returns as approved for all within the `Keys.sol` contract.

**It is worth mentioning that when a buy back or reserve purchase occurs, the entire supply of keys must be bought back at once.** This is to ensure that no matter what, the underlying asset can be reclaimed at a cost. Buy back prices should always be less than or equal to the reserve price. Users that did not create the key are provided with similar functionality related to reserve pricing (`buyAtReserve`) functionality.

#### Accessibility

With reference to the previously mentioned access types, there are a couple of caveats to note when it comes to trading keys via the Key Exchange. On deployment and until regulatory clarity is achieved, keys associated with multi-asset vaults **SHOULD NOT** be tradable. However, the `toggleMultiKeyTrading` function allows the administrator to allow for this at a later point in the future.

Due to regulatory reasons, users with the `RESTRICTED` access type should not be able to create/execute orders/bids. However, the `toggleAllowRestrictedUsers` function allows the administrator to allow for this at a later point in the future.

#### Fees

The Key Exchange does not enforce a fee at the protocol level, but rather denotes a fee within the `Order` and `Bid` struct. When either orders and/or bids are executed, the specified fee will be taken on a per-order basis rather than per-key being traded. Fees are not taken from users when they choose to either lend keys, execute a buy out and/or purchase keys via the reserve pricing functionality.

#### Regarding Key Trading via Buy Out Market

Keys are only tradable once Key Terms have been specified for a given key ID. Additionally, users with the `RESTRICTED` access type within the `AccessRegistry` contract and multi-asset vault keys will be prohibited from trading via the Key Exchange until regulatory clarity is gained.

These requirements are enforced at the protocol level and can be toggled using the `toggleAllowRestrictedUsers` and `toggleMultiKeyTrading` functions which can be called by the administrator of the `KeyExchange` contract.

Touching on user flows, an example flow of Key Trading via the buy out market is as follows:

1. Alice creates a single asset vault with 10 keys.
2. Alice defines the Key Terms related to the key ID associated with her vault via the Key Exchange contract.
   1. She chooses the buy out market and sets a buy out price of 0.1 ether per key and a reserve price and 0.2 ether per key.
3. Alice then signs an EIP712 order off-chain to sell 5 of her keys for 0.2 total.
4. Bob executes this order on-chain and pays 0.2 ether for 5 keys.
5. The original order that Alice signed is now void and cannot be executed again.

From here, let's assume that Alice wants to unlock the original asset for whatever reason. If she wishes to execute a buy out via `executeBuyOut` on the Key Exchange, she will need to recover 5 keys as she is already in possession of the 5 keys that she didn't sell.

Alice will pay 0.5 ether (buy out price is 0.1 ether per key) to Bob and in turn receive the 5 keys that she originally sold. This nets Bob 0.3 ether profit as he originally paid 0.2 ether for 5 keys. From here, the keys are set to the `INACTIVE` state where they can no longer be traded via the Key Exchange and Alice now has the capability to unlock the asset within the vault. It is worth mentioning should Alice choose to transfer keys to another user, she runs the risk of forever losing access to the underlying vault asset in the event the user does not wish to send the key back to her.

Let's replay this example but from the perspective of a user who wishes to conduct a reserve purchase via `buyAtReserve`. Let's say Charlie wishes to unlock the underlying asset as he is a collector of the asset that is within the vault and that the key terms have been fairly defined. Charlie can pay 2 ether (reserve price is 0.2 ether per key) which results in Alice netting 1 ether for her 5 keys and Bob receiving 1 ether for his 5 keys. From here, the keys are set to the `INACTIVE` state where they can no longer be traded via the Key Exchange and Charlie now has the capability to unlock the asset within the vault.

#### Regarding Key Trading via Free Market

Let's assume a scenario where Alice wishes to define her Key Terms, but via the free market instead. One of the caveats of using the free market is that keys can never be recovered via the functionality that is provided in the buy out market, so this market type should be used with great caution. Users of the SegMint protocol will be urged to use the buy out market if asset recovery is critical.

An example flow of Key Trading via the free market is as follows:

1. Alice creates a single asset vault with 10 keys.
2. Alice defines the Key Terms related to the key ID associated with her vault via the Key Exchange contract.
   1. She chooses the free market, which means her buyout price and reserve price per keys are 0 ether. These values are enforced at the protocol level.
3. Alice then signs an EIP712 order off-chain to sell 5 of her keys for 0.2 total.
4. Bob executes this order on-chain and pays 0.2 ether for 5 keys.
5. The original order that Alice signed is now void and cannot be executed again.

Whilst the free market does allow for better price discovery in relation to keys, this means that in order for Alice to unlock the underlying asset from her vault, she must purchase all distributed keys from existing holders via the Key Exchange. This infers that if a user does not wish to sell their key, the underlying asset can never be unlocked.

#### Regarding Royalty Payments

We have opted to implement royalties at the interface level for underlying collections that may be locked within each type of Vault. This is achieved through the inclusion of a `Royalties[]` struct array within both the `Order` and `Bid` structs. Whilst not enforced at the protocol level, all Orders and Bids created through the SegMint platform will prompt the user to pay royalties for the underlying collections if they have been defined.

Context, let's say Alice is an artist who creates a collection and wishes to store her artwork within a Single Asset Vault (SAVault). After verifying that she is the creator of the collection, possibly by signing a message, she will prompted to input her royalty details. This includes the address that will receive the royalty payment and the royalty percentage associated with the keys. This is data that will be stored off-chain and never committed to the protocol at the smart contract level.

After Alice has created her Vault and distributes the keys, whenever someone wishes to sell a key via the SegMint platform, our backend will query the royalty information associated with the keys and calculate the royalty amount to be paid based on the previously provided percentage. After a key has been sold, the protocol should pay Alice the royalty amount to the wallet address she provided prior. If Alice has failed to set this royalty information, the protocol will execute the order as normal with no further royalties being paid to Alice.

In order to prevent Alice from providing a malicious smart contract as her royalty payment address, a small gas stipend is provided with the royalty payment on native token transfers. It is worth mentioning that royalty payments regarding assets locked within Multi-Asset Vaults is yet to be determined, however we wish that the current solution is composable enough to handle royalty payments for these Vaults in the future.

**Considerations**:

- Since the entire supply of keys must be purchased in a single transaction, it is acknowledged that this may be heavily gas intensive. For this reason, we have decided to cap the maximum number of keys that can be created by a vault to 100, this value is defined within the `Keys.sol` contract.
- In addition to the point above, we have also concluded that DoS attacks *should not* be feasible, as keys can only be transferred to KYC'd addresses whereby the appropriate measures will be taken off-chain to ensure that the account registering with the KYC Registry is not a smart contract.
