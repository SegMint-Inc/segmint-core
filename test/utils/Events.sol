// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ISegMintKYCRegistry} from "../../src/interfaces/ISegMintKYCRegistry.sol";

abstract contract Events {
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

    event AccessTypeSet(address indexed account, ISegMintKYCRegistry.AccessType accessType);

    event AccessTypeModified(address indexed admin, address indexed account, ISegMintKYCRegistry.AccessType accessType);
}
