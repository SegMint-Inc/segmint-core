// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SignerManager } from "../../src/SignerManager.sol";

contract SignerManagerMock is SignerManager {
    function initializeSigners(address[] calldata signers, uint96 quorumValue) external {
        _initializeSigners({ signers: signers, quorumValue: quorumValue });
    }

    function sentinelValue() external pure returns (address) {
        return _SENTINEL_VALUE;
    }

    function approvedSigners(address account) external view returns (address) {
        return _approvedSigners[account];
    }

    function signerCount() external view returns (uint256) {
        return _signerCount;
    }
}
