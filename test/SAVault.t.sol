// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract ServiceFactoryTest is BaseTest {
    SAVault public vault;

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

        vault = SAVault(payable(serviceFactory.getSingleAssetVaults({ account: users.alice.account })[0]));

        _;
    }

    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Interface the proxy contract with the implementation so that calls are delegated correctly.
        serviceFactory = ServiceFactory(address(serviceFactoryProxy));
    }

    function test_UnlockAsset_ERC721() public createVault(AssetClass.ERC721) {
        assertEq(mockERC721.ownerOf(0), address(vault));

        uint256 preBurnKeyId = vault.boundKeyId();
        uint256 preBurnKeySupply = vault.getKeyConfig().supply;
        assertEq(keys.balanceOf({ account: users.alice.account, id: preBurnKeyId }), preBurnKeySupply);

        hoax(users.alice.account);
        vault.unlockAsset({ receiver: users.alice.account });

        assertEq(keys.balanceOf({ account: users.alice.account, id: preBurnKeyId }), 0);
        assertEq(mockERC721.ownerOf(0), users.alice.account);
        assertEq(vault.boundKeyId(), 0);

        KeyConfig memory keyConfig = keys.getKeyConfig(preBurnKeyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertTrue(keyConfig.isBurned);
        assertEq(keyConfig.supply, keys.MAX_KEYS());

        Asset memory lockedAsset = vault.lockedAsset();
        assertEq(lockedAsset.class, AssetClass.NONE);
        assertEq(lockedAsset.token, address(0));
        assertEq(lockedAsset.identifier, 0);
        assertEq(lockedAsset.amount, 0);
    }

    function test_UnlockAsset_ERC1155() public createVault(AssetClass.ERC1155) {
        assertEq(mockERC1155.balanceOf({ account: address(vault), id: 0 }), 1);
        assertEq(mockERC1155.balanceOf({ account: users.alice.account, id: 0 }), 0);

        uint256 preBurnKeyId = vault.boundKeyId();
        uint256 preBurnKeySupply = vault.getKeyConfig().supply;
        assertEq(keys.balanceOf({ account: users.alice.account, id: preBurnKeyId }), preBurnKeySupply);

        hoax(users.alice.account);
        vault.unlockAsset({ receiver: users.alice.account });

        assertEq(keys.balanceOf({ account: users.alice.account, id: preBurnKeyId }), 0);
        assertEq(mockERC1155.balanceOf({ account: address(vault), id: 0 }), 0);
        assertEq(mockERC1155.balanceOf({ account: users.alice.account, id: 0 }), 1);
        assertEq(vault.boundKeyId(), 0);

        KeyConfig memory keyConfig = keys.getKeyConfig(preBurnKeyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertTrue(keyConfig.isBurned);
        assertEq(keyConfig.supply, keys.MAX_KEYS());

        Asset memory lockedAsset = vault.lockedAsset();
        assertEq(lockedAsset.class, AssetClass.NONE);
        assertEq(lockedAsset.token, address(0));
        assertEq(lockedAsset.identifier, 0);
        assertEq(lockedAsset.amount, 0);
    }

    function testCannot_UnlockAsset_NoAssetLocked() public createVault(AssetClass.ERC721) {
        startHoax(users.alice.account);
        vault.unlockAsset({ receiver: users.alice.account });
        vm.expectRevert(ISAVault.NoAssetLocked.selector);
        vault.unlockAsset({ receiver: users.alice.account });
    }

    function testCannot_UnlockAsset_InsufficientKeys() public createVault(AssetClass.ERC721) {
        uint256 keyId = vault.boundKeyId();
        uint256 keySupply = vault.getKeyConfig().supply;

        /// Transfer keys to a different user.
        startHoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, keyId, keySupply, "");
        vm.expectRevert(ISAVault.InsufficientKeys.selector);
        vault.unlockAsset({ receiver: users.alice.account });
    }
}