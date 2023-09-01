// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

/// TODO: Safe creation related tests.

contract ServiceFactoryTest is BaseTest {
    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Interface the proxy contract with the implementation so that calls are delegated correctly.
        serviceFactory = ServiceFactory(address(serviceFactoryProxy));
    }

    function test_ServiceFactory_Deployment() public {
        bool result = serviceFactory.hasAllRoles({ user: users.admin, roles: serviceFactory.ADMIN_ROLE() });
        assertTrue(result);

        assertEq(serviceFactory.owner(), address(this));
        assertEq(serviceFactory.maVault(), address(maVault));
        assertEq(serviceFactory.saVault(), address(saVault));
        assertEq(serviceFactory.safe(), address(safe));
        assertEq(serviceFactory.signerRegistry(), signerRegistry);
        assertEq(serviceFactory.kycRegistry(), kycRegistry);
        assertEq(serviceFactory.keys(), keys);
    }

    function test_CreateMultiAssetVault() public {
        (uint256 maNonce,,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: maNonce,
            vaultType: VaultType.MULTI
        });

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.MULTI });
        serviceFactory.createMultiAssetVault(signature);

        (uint256 newMaNonce,,) = serviceFactory.getNonces({ account: users.alice.account });
        assertEq(newMaNonce, maNonce + 1);

        address[] memory maVaults = serviceFactory.getMultiAssetVaults({ account: users.alice.account });
        assertEq(maVaults.length, 1);

        address payable maVault = payable(maVaults[0]);
        uint256 codeSize = 0;
        
        assembly {
            codeSize := extcodesize(maVault)
        }

        assertGt(codeSize, 0);
        assertEq(MAVault(maVault).owner(), users.alice.account);
        assertEq(MAVault(maVault).keys(), keys);
        assertTrue(keys.isRegistered(maVault));
    }

    function test_CreateMultiAssetVault_Many() public {
        uint256 amount = 50;
        bytes memory signature;

        startHoax(users.alice.account);
        for (uint256 i = 0; i < amount; i++) {
            signature = getVaultCreationSignature({ account: users.alice.account, nonce: i, vaultType: VaultType.MULTI });
            
            vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
            emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.MULTI });
            serviceFactory.createMultiAssetVault(signature);
        }
        vm.stopPrank();

        (uint256 maNonce,,) = serviceFactory.getNonces({ account: users.alice.account });
        assertEq(maNonce, amount);

        address[] memory maVaults = serviceFactory.getMultiAssetVaults({ account: users.alice.account });
        assertEq(maVaults.length, amount);

        for (uint256 i = 0; i < maVaults.length; i++) {
            address payable maVault = payable(maVaults[i]);
            uint256 codeSize = 0;
            
            assembly {
                codeSize := extcodesize(maVault)
            }

            assertGt(codeSize, 0);
            assertEq(MAVault(maVault).owner(), users.alice.account);
            assertEq(MAVault(maVault).keys(), keys);
            assertTrue(keys.isRegistered(maVault));
        }
    }

    function testCannot_CreateMultiAssetVault_InvalidAccessType() public {
        (uint256 maNonce,,) = serviceFactory.getNonces({ account: users.eve.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.eve.account,
            nonce: maNonce,
            vaultType: VaultType.MULTI
        });

        hoax(users.eve.account);
        vm.expectRevert(IKYCRegistry.InvalidAccessType.selector);
        serviceFactory.createMultiAssetVault({ signature: signature });
    }

    function testCannot_CreateMultiAssetVault_SignerMismatch_Fuzzed(uint256 randomNonce) public {
        vm.assume(randomNonce > 0);

        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: randomNonce,
            vaultType: VaultType.MULTI
        });

        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        serviceFactory.createMultiAssetVault({ signature: signature });
    }

    function test_CreateSingleAssetVault_ERC721() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC721Asset();
        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        startHoax(users.alice.account);
        /// Approve `serviceFactory` to transfer the asset on callers behalf.
        mockERC721.setApprovalForAll({ operator: address(serviceFactory), approved: true });

        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.SINGLE });
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });
        vm.stopPrank();

        (,uint256 newSaNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        assertEq(newSaNonce, saNonce + 1);

        address[] memory saVaults = serviceFactory.getSingleAssetVaults({ account: users.alice.account });
        assertEq(saVaults.length, 1);

        address payable saVault = payable(saVaults[0]);
        assertTrue(keys.isRegistered(saVault));

        uint256 codeSize = 0;
        assembly {
            codeSize := extcodesize(saVault)
        }
        assertGt(codeSize, 0);

        SAVault vault = SAVault(saVault);
        assertEq(vault.keys(), keys);

        uint256 keyId = vault.boundKeyId();
        assertTrue(keyId != 0);

        KeyConfig memory vaultKeyConfig = vault.getKeyConfig();
        assertEq(vaultKeyConfig.creator, users.alice.account);
        assertEq(vaultKeyConfig.vaultType, VaultType.SINGLE);
        assertFalse(vaultKeyConfig.isFrozen);
        assertFalse(vaultKeyConfig.isBurned);
        assertEq(vaultKeyConfig.supply, keyAmount);

        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertFalse(keyConfig.isBurned);
        assertEq(keyConfig.supply, keyAmount);

        /// Even though the vault pulls the key config from the key contract, we should
        /// guarantee that the values match.
        assertEq(vaultKeyConfig.creator, keyConfig.creator);
        assertEq(vaultKeyConfig.vaultType, keyConfig.vaultType);
        assertEq(vaultKeyConfig.isFrozen, keyConfig.isFrozen);
        assertEq(vaultKeyConfig.isBurned, keyConfig.isBurned);
        assertEq(vaultKeyConfig.supply, keyConfig.supply);
        
        Asset memory lockedAsset = vault.lockedAsset();
        assertEq(lockedAsset.class, asset.class);
        assertEq(lockedAsset.token, asset.token);
        assertEq(lockedAsset.identifier, asset.identifier);
        assertEq(lockedAsset.amount, asset.amount);

        assertEq(keys.keysCreated(), 1);
        assertEq(keys.balanceOf(users.alice.account, keyId), keyConfig.supply);
    }

    function test_CreateSingleAssetVault_ERC1155() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC1155Asset();
        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        startHoax(users.alice.account);
        /// Approve `serviceFactory` to transfer the asset on callers behalf.
        mockERC1155.setApprovalForAll({ operator: address(serviceFactory), approved: true });

        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.SINGLE });
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });
        vm.stopPrank();

        (,uint256 newSaNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        assertEq(newSaNonce, saNonce + 1);

        address[] memory saVaults = serviceFactory.getSingleAssetVaults({ account: users.alice.account });
        assertEq(saVaults.length, 1);

        address payable saVault = payable(saVaults[0]);
        assertTrue(keys.isRegistered(saVault));

        uint256 codeSize = 0;
        assembly {
            codeSize := extcodesize(saVault)
        }
        assertGt(codeSize, 0);

        SAVault vault = SAVault(saVault);
        assertEq(vault.keys(), keys);

        uint256 keyId = vault.boundKeyId();
        assertTrue(keyId != 0);

        KeyConfig memory vaultKeyConfig = vault.getKeyConfig();
        assertEq(vaultKeyConfig.creator, users.alice.account);
        assertEq(vaultKeyConfig.vaultType, VaultType.SINGLE);
        assertFalse(vaultKeyConfig.isFrozen);
        assertFalse(vaultKeyConfig.isBurned);
        assertEq(vaultKeyConfig.supply, keyAmount);

        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertFalse(keyConfig.isBurned);
        assertEq(keyConfig.supply, keyAmount);

        /// Even though the vault pulls the key config from the key contract, we should
        /// guarantee that the values match.
        assertEq(vaultKeyConfig.creator, keyConfig.creator);
        assertEq(vaultKeyConfig.vaultType, keyConfig.vaultType);
        assertEq(vaultKeyConfig.isFrozen, keyConfig.isFrozen);
        assertEq(vaultKeyConfig.isBurned, keyConfig.isBurned);
        assertEq(vaultKeyConfig.supply, keyConfig.supply);
        
        Asset memory lockedAsset = vault.lockedAsset();
        assertEq(lockedAsset.class, asset.class);
        assertEq(lockedAsset.token, asset.token);
        assertEq(lockedAsset.identifier, asset.identifier);
        assertEq(lockedAsset.amount, asset.amount);

        assertEq(keys.keysCreated(), 1);
        assertEq(keys.balanceOf(users.alice.account, keyId), keyConfig.supply);
    }

    function test_CreateSingleAssetVault_Mixed() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset[] memory assets = new Asset[](2);
        assets[0] = getERC721Asset();
        assets[1] = getERC1155Asset();

        startHoax(users.alice.account);
        /// Approve `serviceFactory` to transfer the assets on callers behalf.
        mockERC721.setApprovalForAll({ operator: address(serviceFactory), approved: true });
        mockERC1155.setApprovalForAll({ operator: address(serviceFactory), approved: true });

        for (uint256 i = 0; i < assets.length; i++) {
            bytes memory signature = getVaultCreationSignature({
                account: users.alice.account,
                nonce: i,
                vaultType: VaultType.SINGLE
            });

            vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
            emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.SINGLE });
            serviceFactory.createSingleAssetVault({ asset: assets[i], keyAmount: keyAmount, signature: signature });
        }
        vm.stopPrank();
        
        (,uint256 newSaNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        assertEq(newSaNonce, assets.length);

        address[] memory saVaults = serviceFactory.getSingleAssetVaults({ account: users.alice.account });
        assertEq(saVaults.length, assets.length);
        assertEq(keys.keysCreated(), saVaults.length);

        /// Check state of each vault.
        for (uint256 i = 0; i < saVaults.length; i++) {
            address payable saVault = payable(saVaults[i]);
            assertTrue(keys.isRegistered(saVault));

            uint256 codeSize = 0;
            assembly {
                codeSize := extcodesize(saVault)
            }
            assertGt(codeSize, 0);

            SAVault vault = SAVault(saVault);
            assertEq(vault.keys(), keys);

            uint256 keyId = vault.boundKeyId();
            assertTrue(keyId != 0);

            KeyConfig memory vaultKeyConfig = vault.getKeyConfig();
            assertEq(vaultKeyConfig.creator, users.alice.account);
            assertEq(vaultKeyConfig.vaultType, VaultType.SINGLE);
            assertFalse(vaultKeyConfig.isFrozen);
            assertFalse(vaultKeyConfig.isBurned);
            assertEq(vaultKeyConfig.supply, keyAmount);

            KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
            assertEq(keyConfig.creator, users.alice.account);
            assertEq(keyConfig.vaultType, VaultType.SINGLE);
            assertFalse(keyConfig.isFrozen);
            assertFalse(keyConfig.isBurned);
            assertEq(keyConfig.supply, keyAmount);

            /// Even though the vault pulls the key config from the key contract, we should
            /// guarantee that the values match.
            assertEq(vaultKeyConfig.creator, keyConfig.creator);
            assertEq(vaultKeyConfig.vaultType, keyConfig.vaultType);
            assertEq(vaultKeyConfig.isFrozen, keyConfig.isFrozen);
            assertEq(vaultKeyConfig.isBurned, keyConfig.isBurned);
            assertEq(vaultKeyConfig.supply, keyConfig.supply);
            
            Asset memory lockedAsset = vault.lockedAsset();
            assertEq(lockedAsset.class, assets[i].class);
            assertEq(lockedAsset.token, assets[i].token);
            assertEq(lockedAsset.identifier, assets[i].identifier);
            assertEq(lockedAsset.amount, assets[i].amount);

            assertEq(keys.balanceOf(users.alice.account, keyId), keyConfig.supply);
        }
    }

    function testCannot_CreateSingleAssetVault_InvalidAccessType() public {
        /// Use Alice's asset for Eve, doesn't matter as revert occurs before transfer.
        Asset memory asset = getERC721Asset();

        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.eve.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.eve.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        hoax(users.eve.account);
        vm.expectRevert(IKYCRegistry.InvalidAccessType.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: 1, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_SignerMismatch_Fuzzed(uint256 randomNonce) public {
        vm.assume(randomNonce > 0);

        Asset memory asset = getERC721Asset();
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: randomNonce,
            vaultType: VaultType.SINGLE
        });

        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: 1, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_ZeroAmountValue() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC721Asset();
        asset.amount = 0;

        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        hoax(users.alice.account);
        vm.expectRevert(ISAVault.ZeroAmountValue.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_InvalidAssetType() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC20Asset();
        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        startHoax(users.alice.account);
        vm.expectRevert(ISAVault.InvalidAssetType.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });

        /// Change asset class to type NONE.
        asset.class = AssetClass.NONE;

        vm.expectRevert(ISAVault.InvalidAssetType.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });
        vm.stopPrank();
    }

    function testCannot_CreateSingleAssetVault_Invalid721Amount_Fuzzed(uint256 badAmount) public {
        vm.assume(badAmount > 1);

        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC721Asset();
        asset.amount = badAmount;

        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        hoax(users.alice.account);
        vm.expectRevert(ISAVault.Invalid721Amount.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_InvalidKeyAmount() public {
        uint256 maxKeys = keys.MAX_KEYS();
        uint256 keyAmount = bound(maxKeys, maxKeys + 1, type(uint256).max);

        Asset memory asset = getERC721Asset();

        (,uint256 saNonce,) = serviceFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature({
            account: users.alice.account,
            nonce: saNonce,
            vaultType: VaultType.SINGLE
        });

        hoax(users.alice.account);
        vm.expectRevert(IKeys.InvalidKeyAmount.selector);
        serviceFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, signature: signature });
    }
}
