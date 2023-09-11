# SegMint Vault & Key Access Control

## Roles and Abilities

Within the SegMint ecosystem, all contracts will be deployed and acknowledge the deployer as the main owner of all contracts. However, an address that will be granted the `ADMIN_ROLE` will be specified within the constructor of all main contracts.

The owner of these contracts should never/rarely interact with the chain post-deployment unless it is to grant/revoke admin privileges to another account in the event of a compromise. The administrator will be responsible for calling most permissioned state-changing functions.

## Definitions

*Contract Owner*: The owner of the contract, in this context this will namely be the deployer of the contracts or the creator of a multi-asset vault.

*Administrator*: Any account that has been granted the `ADMIN_ROLE`.

*Factory Role*: A role that should **only** be held by the Vault Factory.

*Registered Vault*: An address that has been registered with the Keys contract via the Vault Factory.

*KYC'd User*: Any account that has been associated with the `UNRESTRICTED` or `RESTRICTED` access types via the KYC Registry.

*Key Creator*: The account that originally minted the keys.

*Key Holder*: The account that holds the entire key supply of a given ID associated with a vault.

*Anyone*: Any EOA.

### Signer Registry

**Administrator**: Can update the signer address.

**Anyone**: Can view the signer address.

### KYC Registry

**Administrator**: Can update the signer registry address and modify a user's access type.

**Anyone**: Can update the access type associated with their account **assuming** they have KYC'd with the SegMint platform and our backend verifies the address sending the transaction.

### Vault Factory

**Administrator**: Can propose, cancel and execute an upgrade via the inherited `UpgradeHandler` logic.

**Factory Role (self)**: Can register vault addresses with the ERC1155 Keys contract.

**KYC'd Users**: Can create single-asset or multi-asset vaults **assuming** the backend API has allowed them to do so.

**Anyone**: Can view the vault addresses and nonces associated with an account.

### Single Asset Vaults (SAVault)

**KeyHolder**: Can unlock the underlying asset.

**Anyone**: Can view the locked asset and the associated key information associated with the vault.

### Multi Asset Vaults

**Contract Owner**: Can unlock assets/native token and bind keys to a vault.

**Key Holder**: Can unlock assets/native token and unbind keys from a vault.

**Anyone**: Can view the locked assets and the associated key information associated with the vault.

### Keys

**Contract Owner**: Can set the Key Exchange address, this is done during deployment.

**Administrator**: Can freeze and unfreeze specific key IDs as well as set a URI for metadata.

**Factory Role**: Can register vaults.

**Registered Vault**: Can create and burn keys.

**KYC'd Users**: Can lend out and reclaim keys.

**Anyone**: Can view the active lends associated with a given key ID.

### Key Exchange

**Adminstrator**: Can toggle the trading of multi-asset vault keys, set a new protocol fee and fee receiver.

**Key Creator**: Can define the terms associated with a key ID and execute a buy back.

**KYC'd Users**: Can execute/cancel orders/bids and execute a purchase of keys at the reserve price **assuming** the correct key terms have been defined.

**Anyone**: Can view any exchange related data such as cancelled orders/bids.
