// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { ISegMintVaultManagerProxy } from "./interfaces/ISegMintVaultManagerProxy.sol";

contract SegMintVaultManagerProxy is ISegMintVaultManagerProxy, ERC1967Proxy {
    constructor(address admin_, address implementation_, bytes memory payload_)
        ERC1967Proxy(implementation_, payload_)
    { }

    /**
     * @inheritdoc ISegMintVaultManagerProxy
     */
    function implementation() external view override returns (address) {
        return _getImplementation();
    }
}