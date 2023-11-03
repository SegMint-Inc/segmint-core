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
| `OperatorFilter.sol` | Whitelists contracts that are able to move Keys on behalf of users. |
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

## Deployment

In order to deploy the protocol using Foundry, the following steps must be taken:

1. Review the `Constants.json` file provided in `./script/constants/` and ensure the addresses provided are correct, these values may vary depending on the chain that the protocol is being deployed on. In the context of Ethereum Mainnet, `wrappedEther` should be the canonical [WETH9](https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) address. On other chains, you will need to provide the canonical wrapped native token address. `admin`, `signer` and `feeReceiver` are all addresses that are up to the discretion of the deployer.
2. Once `Constants.json` has been validated, create a `.env` file that mimics `.env.example` provided in the root directory of this repository and substitute the necessary values. `DEFAULT_FORK_BLOCK` is negliable and can be ignored and `ETHERSCAN_API_KEY` can be ignored if there is no intention to verify the contracts.
3. After the `.env` file has been validated, load the file into the local environment by using the `source .env` command within your terminal.
4. Simulate the deployment of the protocol using the following command `forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --slow --watch --broadcast -vvvv`.
5. If you plan to deploy the protocol and verify the contracts in the process, simply append `--verify $ETHERSCAN_API_KEY` to the command above.

Note: Additional RPC URLs to different chains will be required if you plan to deploy the protocol to a chain other than Ethereum Mainnet. These can be added at your discretion and simply replace `$MAINNET_RPC_URL` with the identifier you have provided in the `.env` file. Ensure to reload the updated config in to your environment using `source .env` if required.
