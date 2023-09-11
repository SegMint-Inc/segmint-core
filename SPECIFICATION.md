# SegMint Vault & Key Specification

The SegMint Vault & Key ecosystem represents a fractionalized NFT protcol. Vaults are integral to SegMint's Lock & Key Model, where users secure their assets within a SegMint Vault and create SegMint Keys, a representation of the underlying asset in the form of fractionalization. These keys take the form of ERC-1155 tokens and represent a semi-fungible counterpart to the locked asset(s). Vaults come in two main types:

- **Single-Asset Vaults**: These are designed for safeguarding a single, locked asset. If the locked asset resembles an NFT (Non-Fungible Token), the SegMint Keys generated may bear a visual representation that matches the underlying asset.
- **Multi-Asset Vaults**: These versatile vaults enable the creation of a basket of assets, which may consist of various token types, including fungible and non-fungible assets. The visual representation of the assets within these vaults may be customized to suit the user's preferences.

## Definitions

*Keys* - An ERC1155 token used to unlock assets contained within vaults. It is worth mentioning that this representation of access control can be circumstantial and will be explained at a later point in this document.
*Single-Asset Vault* - A smart contract that holds a single underlying asset.
*Multi-Asset Vault* - A smart contract that holds multiple underlying assets.
*Key Exchange* - A smart contract used to facilitate atomic trades of Keys utilising the native token and the wrapped native token equivalent. In the context of Ethereum, this would represent **ETH** and the canonical **WETH** implementation in respective order.
*Wallet* - An EOA account owned by a user of the SegMint platform.
*Order* - Represents a sell intent on the SegMint Key Exchange.

## Protocol Upgradability

The majority of the smart contracts within the Vault & Key ecosystem are immutable with the exception of the `VaultFactory.sol` contract. This contract has been made upgradeable by choice in the chance future vault variations wanted to be provided to the end user.

## Registries

### Signer Registry

The `SignerRegistry.sol` contract is used as a single source of truth for the current signer address. Since ECDSA signatures which are created through a back-end API are required for some components of the ecosystem, I have opted to create a signer registry for this purpose so that in the event the signer needs to be updated, this can be done with a single transaction rather than multiple. It contains one state-changing function which can only be called by the administrator of the contract that updates the current signer address.


### KYC Registry

The `KYCRegistry.sol` contract is used to manage KYC verified wallets and the access type associated with them. Since the Vault and Key ecosystem is closed and only KYC'd wallets are allowed to participate and interact with these services, the KYC Registry can be queried to view the access type associated with a given wallet.

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

The `VaultFactory.sol` contract is used to create both single-asset and multi-asset vaults. This contract has been made upgradeable due to the point that can be found [here](#protocol-upgradability). It is worth mentioning that whilst this contract is upgradable, a strict 5 day timelock has been implemented via the `UpgradeHandler.sol` smart contract. This is to ensure that in the event a SegMint administrator is compromised and wants to brick the Factory, the team has 5 days notice to remedy the situation.

In order to keep the creation of these vaults gas efficient, I have opted to use clones for the creation of each vault type. The implementation addresses for both vault types will be provided to the ERC1967 proxy via the constructor upon deployment. The terms `maVault` and `saVault` refer to the multi-asset and single-asset vault implementations respectively. To prevent storing the addressess for each vault type of each user in storage, I have also opted to utilise a nonce system that is similar to the way UniSwap V2 handles pair prediction.

The address of the caller which is derived from `msg.sender` and the nonce are hashed together to create a salt that is used in conjunction with `CREATE2` to create vaults. A simply function `_predictDeployments()` is used to derive the addresses of al vaults created by each user.

## Vaults

### Single Asset Vault (SAVault)

The `SAVault.sol` contract contains the implementation logic for single-asset vaults.

When a single-asset vault is created, the underlying asset which can only be an ERC721 or ERC1155 token/s (for regulatory reasons) is transferred to the newly created vault and the specified number of keys are minted to the user, this entire process is atomic. Since key creation is atomic, single-asset vaults have no concept of a vault owner and instead use the associated key's ID supply holder for access control.

When the underlying asset is unlocked, all keys of the ID associated with the vault will be burnt and the underlying asset will be transferred to the caller. From here, the vault is essentially bricked and cannot be reused.

### Multi Asset Vaults (MAVault)

The `MAVault.sol` contract contains the implementation logic for multi-asset vaults.

When a multi-asset vault is created, the user can then choose to transfer any number of assets (all token standards eligable as well as native token) non-atomically to the vault and then create keys at a later point in time once the basket of assets has been finalised. Due to this design, multi-asset vaults have a concept of contextual ownership.

When no keys are binded, the creator of the vault is free to withdraw assets and native token from the vault until they decide to bind keys. Once keys are binded, only the vaults associated key ID supply holder can withdraw assets from the vault.

Since a large number of underlying assets can be contained within a multi-asset vault, the unlocking assets process is non-atomic and allows for the key's supply holder to burn the keys at a later point in time once they are finished.

One quirk about multi-asset vaults is that once the key's associated with the vault are burnt, the vault reverts back to its "original" state where the owner can reuse it if they wish to do so.

## Key Services

### Keys

The `Keys.sol` contract contains all the logic associated with Keys. Keys should only be mintable by vaults and only a single key ID should be associated with a given vault at any given time. The function `isRegistered` which can only be called by the Vault Factory, provides access control for vaults to call the `createKeys` function. For single-asset vaults, this is done atomically in the same transaction that the vault is created. For multi-asset vaults, the owner can call this function directly through the vault when they have finished depositing assets.

One notable feature of keys is that they can be lended out to other KYC'd users of the platform for a duration of time. E.g. Alice has a multi-asset vault with 10 keys bounded to it and wants to lend 1 key to Bob. Alice lends Bob 1 key for 3 days. Whilst Bob is in possession of this lended key, he should never be able to sell it or transfer it to another user, this key should be soulbound.

However, if Bob purchases 1 key of the same key ID (whereby he now holds two), he should be able to freely sell 1 key whilst in possession of the lended key. Whilst not transferrable, it can be returned to Alice by either a direct transfer using `safeTransferFrom` or by Alice calling the `reclaimKey` function after the lending period has lapsed.

It is be design that only one lend can be active for a lendee for a given key ID at any point in time. E.g.If Alice lends Bob key ID #1, Charles cannot lend out the same key ID to Bob. However, Charles can lend Bob the desired amount of keys for key ID #2. The above stated principle holds true for all conditions.

Due to regulatory compliance, SegMint has opted to implement the freezing of Keys to comply with possible requests from authoritative bodies. This means that in the event Eve is suspected to be a bad actor who has **created** keys, an administrator can freeze the respective key ID and subsequently, the underlying assets within her associated vault.

Subsequently, due to the requirements of SegMints buyback and reserve purchase requests, the `isApprovedForAll` function has been overridden to allow for the Key Exchange contract to facilitate these actions. This will be explained below.

### Key Exchange

The `KeyExchange.sol` contract is used to facilitate the trading of Keys. It is acknowledged that whilst trading could be faciliated on other platforms such as OpenSea, it would require both the seller and the buyer to be KYC'd, this is considered fine.

Sellers of a given key ID will sign orders off-chain which will be made viewable via the platform website for buyers to act upon. If a seller wishes to increase the listing price of a given order, they will be required to send a transaction that acknowledges the previous order hash to be void and unactionable. If the inverse scenario occurs where a seller wants to reduce the listing price of a given order, they will *not* require a stateful transaction and instead the higher priced listing will be removed from the website.

Buyers are able to place bids using the wrapped native token which can be actioned upon by parties that hold the respective asset in the desired quantity. Since keys are ERC1155, I decided to take a similar approach to most marketplaces where a bid is considered on the overall key ID rather than a specified listing.

Before any trading can take place, the creator of the key (the user who minted them) must define the associated keys terms. Terms can be defined under two market conditions, and relate the the `IKeyExchange.MarketType` enum, these are as follows:

| Enum Value | Description |
|------------|-------------|
| **UNDEFINED** | No key terms have been set. |
| **FREE** | Free market, no buyout or reserve functionality can be actioned. |
| **BUYOUT** | Buyout market, key creator can perform buyouts and users can execute reserve purchases. |

#### Free Market

If a user has chosen to sell their keys on the free market, they are unable to perform a buy out or reserve purchase for the desired keys. In order for a user to reclaim the underlying asset/s from a vault, they must reacquire the keys through some means.

#### Buy Out Market

If a user has chosen the buy out market, they will be required to define a buy back price and a reserve price. The difference between these two pricing models is that only the creator can execute a buy back which essentially takes a specified number of keys from each of the holders provided and pays them the respective amount owed. E.g. Alice requires 10 keys to unlock the asset from her vault but only holds 7 of them, if she has set a buy back price of 0.1 Ether, she can pay Bob who holds 3 keys 0.3 Ether and forcefully take them back. **It is worth mentioning that when a buy back occurs, the entire supply of keys must be bought back at once.** This is to ensure that no matter what, the underlying asset can be reclaimed at a cost.

Non-creators are provided with similar functionality related to reserve pricing, however they do not need to conduct an entire supply purchase when acquiring keys through the reserve pricing method.

**Considerations**:

- Since the entire supply of keys must be purchased in a single transaction, it is acknowledged that this may be heavily gas intensive. For this reason, we have decided to cap the maximum number of keys that can be created by a vault to 100, this value is defined within the `Keys.sol` contract.
- In addition to the point above, we have also concluded that DoS attacks *should not* be feasible, as keys can only be transferred to KYC'd addresses whereby the appropriate measures will be taken off-chain to ensure that the account registering with the KYC Registry is not a smart contract.
  