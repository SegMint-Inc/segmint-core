// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract ServiceFactoryTest is BaseTest {

    /// Creates a single-asset vault for Alice and locks the respective asset class.
    modifier createVault(AssetClass assetClass) {
        startHoax(users.alice.account);
        
        Asset memory asset;
        if (assetClass == AssetClass.ERC721) {
            asset = getERC721Asset();
            mockERC721.setApprovalForAll({ operator: address(serviceFactory), approved: true });
        } else {
            asset = getERC1155Asset();
            mockERC1155.setApprovalForAll({ operator: address(serviceFactory), approved: true });
        }

        serviceFactory.createSingleAssetVault({
            asset: asset,
            keyAmount: keys.MAX_KEYS(),
            signature: getVaultCreationSignature(users.alice.account, 0, VaultType.SINGLE)
        });

        vm.stopPrank();

        _;
    }

    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        // Create a new vault with the maximum number keys.
        startHoax(users.alice.account);
        mockERC721.setApprovalForAll({ operator: address(serviceFactoryProxy), approved: true });
        ServiceFactory(address(serviceFactoryProxy)).createSingleAssetVault({
            asset: getERC721Asset(),
            keyAmount: keys.MAX_KEYS(),
            signature: getVaultCreationSignature(users.alice.account, 0, VaultType.SINGLE)
        });
        vm.stopPrank();
    }

    /**
     * @dev The reason thorough unit testing for the `createKeys()` function is not conducted here
     * is that this function should only be invoked by vaults. For this reason, unit tests relating
     * to this function can be found within `ServiceFactory.t.sol` and `MAVault.t.sol`.
     * - Single Asset Vault keys are minted upon creation.
     * - Multi Asset Vault keys are minted at the vault owners discretion.
     */

    function testCannot_CreateKeys_CallerNotRegistered_Fuzzed(address nonVault) public {
        uint256 maxKeys = keys.MAX_KEYS();
        
        hoax(nonVault);
        vm.expectRevert(IKeys.CallerNotRegistered.selector);
        keys.createKeys({ amount: maxKeys, receiver: nonVault, vaultType: VaultType.SINGLE });
    }

}