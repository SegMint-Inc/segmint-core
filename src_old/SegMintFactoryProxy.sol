// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { ISegMintFactoryProxy } from "./interfaces/ISegMintFactoryProxy.sol";

/**
 * @title ISegMintFactoryProxy
 * @notice See documentation of {ISegMintFactoryProxy}.
 */

contract SegMintFactoryProxy is ISegMintFactoryProxy, ERC1967Proxy {
    /// forgefmt: disable-next-item
    constructor(
        address admin_,
        address implementation_,
        bytes memory payload_
    ) ERC1967Proxy(implementation_, payload_) { }

    /**
     * @inheritdoc ISegMintFactoryProxy
     */
    function implementation() external view override returns (address) {
        return _implementation();
    }
}
