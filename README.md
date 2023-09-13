# Segmint Vault & Keys

Core contracts for the SegMint Vault & Key ecosystem, a fractionalized asset protocol.

See `./SPECIFICATION.md` for further details.

## Protocol Overview

### Registry Contracts

| File Name | Description |
| --- | --- |
| `SignerRegistry.sol` | Returns the current signer address for relevant contracts. |
| `KYCRegistry.sol` | Updates and returns a users access type within the ecosystem. |

### Factories

| File Name | Description |
| --- | --- |
| `VaultFactory.sol` | Used to create single-asset and multi-asset vaults. |

### Vaults

| File Name | Description |
| --- | --- |
| `SAVault.sol` | Holds a singular asset which can be unlocked with keys. |
| `MAVault.sol` | Holds a basket of assets which can be unlocked with keys. |

### Key Services

| File Name | Description |
| --- | --- |
| `Keys.sol` | Protocol ERC1155, tokens that represent the fractionalized assets within a vault. |
| `KeyExchange.sol` | Facilitates the trading of keys in exchange for value. |

### Handlers

| File Name | Description |
| --- | --- |
| `UpgradeHandler.sol` | Used for managing upgrades to the Vault Factory contract using a timelock. |
| `ExchangeHasher.sol` | Returns the EIP712 equivalent hashes of an Order and Bid.

### Managers

| File Name | Description |
| --- | --- |
| `NonceManager.sol` | Handles user nonces within the Key Exchange, allows for mass order and/or bid cancellation. |

## Testing

This repository uses Foundry for testing and deployment.

```cmd
forge install
forge build
forge test
```

## Access Control

See `PERMISSIONS.md` for further details.

## Deplyoment

TBD.
