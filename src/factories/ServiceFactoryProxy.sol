// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { IServiceFactoryProxy } from "../interfaces/IServiceFactoryProxy.sol";

/**
 * @title ServiceFactoryProxy
 * @notice See documentation of {IServiceFactoryProxy}.
 */

contract ServiceFactoryProxy is IServiceFactoryProxy, ERC1967Proxy {
    constructor(address implementation_, bytes memory payload_) ERC1967Proxy(implementation_, payload_) { }

    /**
     * @inheritdoc IServiceFactoryProxy
     */
    function implementation() external view returns (address) {
        return _implementation();
    }
}
