// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract VaultFactoryTest is BaseTest {
    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.
    }

    function test_VaultFactory_Deployment() public {
        bool result = vaultFactory.hasAllRoles({ user: users.admin, roles: AccessRoles.ADMIN_ROLE });
        assertTrue(result);

        assertEq(vaultFactory.owner(), address(this));
        assertEq(vaultFactory.maVault(), address(maVault));
        assertEq(vaultFactory.saVault(), address(saVault));
        assertEq(vaultFactory.signerRegistry(), signerRegistry);
        assertEq(vaultFactory.accessRegistry(), accessRegistry);
        assertEq(vaultFactory.keys(), keys);

        (string memory name, string memory version) = vaultFactory.nameAndVersion();
        assertEq(name, "Vault Factory");
        assertEq(version, "1.0");
    }

    function testCannot_Initialize_VaultFactory_Implementation() public {
        /// @dev Since we cast the original implementation in `Base.sol` to the proxy, we need to
        /// load the EIP-1967 slot to get the true implementation address.
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 vaultFactoryImplementation = vm.load(address(vaultFactory), implementationSlot);
        address implementation = address(uint160(uint256(vaultFactoryImplementation)));

        hoax(users.eve.account);
        vm.expectRevert("Initializable: contract is already initialized");
        VaultFactory(implementation).initialize({
            admin_: users.eve.account,
            maVault_: address(0),
            saVault_: address(0),
            signerRegistry_: ISignerRegistry(address(0)),
            accessRegistry_: IAccessRegistry(address(0)),
            keys_: IKeys(address(0))
        });
    }

    function testCannot_Initialize_VaultFactory_Admin_ZeroAddressInvalid() public {
        VaultFactory testVaultFactory = new VaultFactory();
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                address(0), // admin
                address(maVault),
                address(saVault),
                ISignerRegistry(signerRegistry),
                IAccessRegistry(accessRegistry),
                IKeys(keys)
            )
        });
    }

    function testCannot_Initialize_VaultFactory_MAVault_ZeroAddressInvalid() public {
        VaultFactory testVaultFactory = new VaultFactory();
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                users.admin,
                address(0),  // MAVault
                address(saVault),
                ISignerRegistry(signerRegistry),
                IAccessRegistry(accessRegistry),
                IKeys(keys)
            )
        });
    }

    function testCannot_Initialize_VaultFactory_SAVault_ZeroAddressInvalid() public {
        VaultFactory testVaultFactory = new VaultFactory();
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                users.admin,
                address(maVault),
                address(0),  // SAVault
                ISignerRegistry(signerRegistry),
                IAccessRegistry(accessRegistry),
                IKeys(keys)
            )
        });
    }

    function testCannot_Initialize_VaultFactory_SignerRegistry_ZeroAddressInvalid() public {
        VaultFactory testVaultFactory = new VaultFactory();
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                users.admin,
                address(maVault),
                address(saVault),
                ISignerRegistry(address(0)),  // SignerRegistry
                IAccessRegistry(accessRegistry),
                IKeys(keys)
            )
        });
    }

    function testCannot_Initialize_VaultFactory_AccessRegistry_ZeroAddressInvalid() public {
        VaultFactory testVaultFactory = new VaultFactory();
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                users.admin,
                address(maVault),
                address(saVault),
                ISignerRegistry(signerRegistry),
                IAccessRegistry(address(0)),  // AccessRegistry
                IKeys(keys)
            )
        });
    }

    function testCannot_Initialize_VaultFactory_Keys_ZeroAddressInvalid() public {
        VaultFactory testVaultFactory = new VaultFactory();
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                users.admin,
                address(maVault),
                address(saVault),
                ISignerRegistry(signerRegistry),
                IAccessRegistry(accessRegistry),
                IKeys(address(0))
            )
        });
    }

    function testCannot_Initialize_Twice() public {
        hoax(users.eve.account);
        vm.expectRevert("Initializable: contract is already initialized");
        vaultFactory.initialize({
            admin_: users.eve.account,
            maVault_: address(0),
            saVault_: address(0),
            signerRegistry_: ISignerRegistry(address(0)),
            accessRegistry_: IAccessRegistry(address(0)),
            keys_: IKeys(address(0))
        });
    }

    function test_CreateMultiAssetVault_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());

        (uint256 maNonce,) = vaultFactory.getNonces(users.alice.account);
        assertEq(maNonce, 0);

        bytes memory signature = getVaultCreationSignature(users.alice.account, maNonce, VaultType.MULTI);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.MULTI, signature: signature });
        vaultFactory.createMultiAssetVault({ keyAmount: keyAmount, delegateAssets: false, signature: signature });

        (uint256 newMaNonce,) = vaultFactory.getNonces(users.alice.account);
        assertEq(newMaNonce, maNonce + 1);

        address[] memory maVaults = vaultFactory.getMultiAssetVaults({ account: users.alice.account });
        assertEq(maVaults.length, 1);

        address payable maVault = payable(maVaults[0]);
        assertTrue(keys.isRegistered(maVault));

        MAVault vault = MAVault(maVault);
        assertEq(vault.owner(), users.alice.account);
        assertEq(vault.keys(), keys);
        assertEq(vault.boundKeyId(), 1);
    }

    function test_CreateMultiAssetVault_Many_Fuzzed(uint256 amount) public {
        amount = bound(amount, 2, 10);
        bytes memory signature;

        startHoax(users.alice.account);
        for (uint256 i = 0; i < amount; i++) {
            signature = getVaultCreationSignature(users.alice.account, i, VaultType.MULTI);

            vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
            emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.MULTI, signature: signature });
            vaultFactory.createMultiAssetVault(i + 1, false, signature);
        }
        vm.stopPrank();

        (uint256 maNonce,) = vaultFactory.getNonces({ account: users.alice.account });
        assertEq(maNonce, amount);

        address[] memory maVaults = vaultFactory.getMultiAssetVaults({ account: users.alice.account });
        assertEq(maVaults.length, amount);

        for (uint256 i = 0; i < maVaults.length; i++) {
            address payable maVault = payable(maVaults[i]);
            assertTrue(keys.isRegistered(maVault));

            MAVault vault = MAVault(maVault);
            assertEq(vault.owner(), users.alice.account);
            assertEq(vault.keys(), keys);
        }
    }

    function test_CreateMultiAssetVault_WithDelegation() public {
        bytes memory signature = getVaultCreationSignature(users.alice.account, 0, VaultType.MULTI);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit DelegationPerformed({ delegationHash: 0x4fd98b4ab70d00e9fd2b80daf2480ad1b0e9e320468f35effbeb4489cb32e001 });
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.MULTI, signature: signature });
        vaultFactory.createMultiAssetVault({ keyAmount: 100, delegateAssets: true, signature: signature });

        address delegationVault = vaultFactory.getMultiAssetVaults({ account: users.alice.account })[0];

        IDelegateRegistry.Delegation[] memory delegations = delegateRegistry.getOutgoingDelegations(delegationVault);
        assertEq(delegations.length, 1);
        assertEq(delegations[0].type_, IDelegateRegistry.DelegationType.ALL);
        assertEq(delegations[0].to, users.alice.account);
        assertEq(delegations[0].from, delegationVault);
        assertEq(delegations[0].contract_, address(0));
        assertEq(delegations[0].tokenId, 0);
        assertEq(delegations[0].amount, 0);
    }

    function testCannot_CreateMultiAssetVault_InvalidAccessType() public {
        (uint256 maNonce,) = vaultFactory.getNonces(users.eve.account);
        bytes memory signature = getVaultCreationSignature(users.eve.account, maNonce, VaultType.MULTI);

        hoax(users.eve.account);
        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        vaultFactory.createMultiAssetVault({ keyAmount: 1, delegateAssets: false, signature: signature });
    }

    function testCannot_CreateMultiAssetVault_SignerMismatch_Fuzzed(uint256 randomNonce) public {
        vm.assume(randomNonce > 0);

        bytes memory signature = getVaultCreationSignature(users.alice.account, randomNonce, VaultType.MULTI);

        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        vaultFactory.createMultiAssetVault({ keyAmount: 1, delegateAssets: false, signature: signature });
    }

    function test_CreateSingleAssetVault_ERC721_WithDelegation_Fuzzed() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC721Asset();

        (uint256 maNonce, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        assertEq(maNonce, 0);
        assertEq(saNonce, 0);

        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        /// Approve `vaultFactory` to transfer the asset on callers behalf.
        startHoax(users.alice.account);
        mockERC721.setApprovalForAll({ operator: address(vaultFactory), approved: true });

        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.SINGLE, signature: signature });
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: true, signature: signature });

        (, uint256 newSaNonce) = vaultFactory.getNonces({ account: users.alice.account });
        assertEq(newSaNonce, saNonce + 1);

        address[] memory saVaults = vaultFactory.getSingleAssetVaults({ account: users.alice.account });
        assertEq(saVaults.length, 1);

        address payable saVault = payable(saVaults[0]);
        assertTrue(keys.isRegistered(saVault));

        SAVault vault = SAVault(saVault);
        assertEq(vault.keys(), keys);

        bytes32[] memory delegationHashes = new bytes32[](1);
        delegationHashes[0] = 0xe1ad6c25371c70191567b905adf6873640932a4f95fc14f718520fa8fe24cf01;  // Hardcoded hash.
        IDelegateRegistry.Delegation[] memory delegations = vault.DELEGATE_V2_REGISTRY().getDelegationsFromHashes(delegationHashes);
        assertEq(delegations.length, 1);
        assertEq(delegations[0].type_, IDelegateRegistry.DelegationType.ALL);
        assertEq(delegations[0].to, users.alice.account);
        assertEq(delegations[0].from, saVault);
        assertEq(delegations[0].contract_, address(0));
        assertEq(delegations[0].tokenId, 0);
        assertEq(delegations[0].amount, 0);

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
        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        startHoax(users.alice.account);
        /// Approve `vaultFactory` to transfer the asset on callers behalf.
        mockERC1155.setApprovalForAll({ operator: address(vaultFactory), approved: true });

        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
        emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.SINGLE, signature: signature });
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });
        vm.stopPrank();

        (, uint256 newSaNonce) = vaultFactory.getNonces({ account: users.alice.account });
        assertEq(newSaNonce, saNonce + 1);

        address[] memory saVaults = vaultFactory.getSingleAssetVaults({ account: users.alice.account });
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
        /// Approve `vaultFactory` to transfer the assets on callers behalf.
        mockERC721.setApprovalForAll({ operator: address(vaultFactory), approved: true });
        mockERC1155.setApprovalForAll({ operator: address(vaultFactory), approved: true });

        for (uint256 i = 0; i < assets.length; i++) {
            bytes memory signature =
                getVaultCreationSignature({ account: users.alice.account, nonce: i, vaultType: VaultType.SINGLE });

            vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: true, checkData: true });
            emit VaultCreated({ user: users.alice.account, vault: address(0), vaultType: VaultType.SINGLE, signature: signature });
            vaultFactory.createSingleAssetVault({ asset: assets[i], keyAmount: keyAmount, delegateAsset: false, signature: signature });
        }
        vm.stopPrank();

        (, uint256 newSaNonce) = vaultFactory.getNonces({ account: users.alice.account });
        assertEq(newSaNonce, assets.length);

        address[] memory saVaults = vaultFactory.getSingleAssetVaults({ account: users.alice.account });
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

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.eve.account });
        bytes memory signature =
            getVaultCreationSignature({ account: users.eve.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        hoax(users.eve.account);
        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: 1, delegateAsset: false, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_SignerMismatch_Fuzzed(uint256 randomNonce) public {
        vm.assume(randomNonce > 0);

        Asset memory asset = getERC721Asset();
        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: randomNonce, vaultType: VaultType.SINGLE });

        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: 1, delegateAsset: false, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_ZeroAmountValue() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC721Asset();
        asset.amount = 0;

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        hoax(users.alice.account);
        vm.expectRevert(ISAVault.ZeroAssetAmount.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_InvalidAssetType() public {
        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC20Asset();
        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        startHoax(users.alice.account);
        vm.expectRevert(ISAVault.InvalidAssetType.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });

        /// Change asset class to type NONE.
        asset.class = AssetClass.NONE;

        vm.expectRevert(ISAVault.InvalidAssetType.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });
        vm.stopPrank();
    }

    function testCannot_CreateSingleAssetVault_Invalid721Amount_Fuzzed(uint256 badAmount) public {
        vm.assume(badAmount > 1);

        uint256 keyAmount = keys.MAX_KEYS();

        Asset memory asset = getERC721Asset();
        asset.amount = badAmount;

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        hoax(users.alice.account);
        vm.expectRevert(ISAVault.Invalid721Amount.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });
    }

    function testCannot_CreateSingleAssetVault_InvalidKeyAmount() public {
        uint256 maxKeys = keys.MAX_KEYS();
        uint256 keyAmount = bound(maxKeys, maxKeys + 1, type(uint256).max);

        Asset memory asset = getERC721Asset();

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature =
            getVaultCreationSignature({ account: users.alice.account, nonce: saNonce, vaultType: VaultType.SINGLE });

        hoax(users.alice.account);
        vm.expectRevert(IKeys.InvalidKeyAmount.selector);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });
    }

    function test_ProposeUpgrade() public {
        uint40 expectedDeadline = uint40(block.timestamp + vaultFactory.UPGRADE_TIMELOCK());

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit UpgradeProposed({ admin: users.admin, implementation: mockUpgrade, deadline: expectedDeadline });
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });

        (address implementation, uint40 deadline) = vaultFactory.upgradeProposal();

        assertEq(implementation, mockUpgrade);
        assertEq(deadline, expectedDeadline);
    }

    function testCannot_ProposeUpgrade_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });
    }

    function testCannot_ProposeUpgrade_ZeroAddressInvalid() public {
        hoax(users.admin);
        vm.expectRevert(IVaultFactory.ZeroAddressInvalid.selector);
        vaultFactory.proposeUpgrade({ newImplementation: address(0) });
    }

    function testCannot_ProposeUpgrade_ProposalInProgress() public {
        startHoax(users.admin);
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });
        vm.expectRevert(IUpgradeHandler.ProposalInProgress.selector);
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });
    }

    function test_CancelUpgrade() public {
        startHoax(users.admin);
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });

        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit UpgradeCancelled({ admin: users.admin, implementation: mockUpgrade });
        vaultFactory.cancelUpgrade();

        (address implementation, uint40 deadline) = vaultFactory.upgradeProposal();
        assertEq(implementation, address(0));
        assertEq(deadline, 0);
    }

    function testCannot_CancelUpgrade_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultFactory.cancelUpgrade();
    }

    function testCannot_CancelUpgrade_NoProposalExists() public {
        hoax(users.admin);
        vm.expectRevert(IUpgradeHandler.NoProposalExists.selector);
        vaultFactory.cancelUpgrade();
    }

    function test_ExecuteUpgrade() public {
        (string memory name, string memory version) = vaultFactory.nameAndVersion();
        assertEq(name, "Vault Factory");
        assertEq(version, "1.0");

        startHoax(users.admin);
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });

        (, uint40 deadline) = vaultFactory.upgradeProposal();
        vm.warp(deadline);

        vaultFactory.executeUpgrade("");

        (name, version) = vaultFactory.nameAndVersion();
        assertEq(name, "Upgraded Vault Factory");
        assertEq(version, "2.0");

        /// Ensure that all previous defined storage values are retained after upgrade.
        bool result = vaultFactory.hasAllRoles({ user: users.admin, roles: AccessRoles.ADMIN_ROLE });
        assertTrue(result);

        assertEq(vaultFactory.owner(), address(this));
        assertEq(vaultFactory.maVault(), address(maVault));
        assertEq(vaultFactory.saVault(), address(saVault));
        assertEq(vaultFactory.signerRegistry(), signerRegistry);
        assertEq(vaultFactory.accessRegistry(), accessRegistry);
        assertEq(vaultFactory.keys(), keys);
    }

    function testCannot_ExecuteUpgrade_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultFactory.executeUpgrade({ payload: "" });
    }

    function testCannot_ExecuteUpgrade_NoProposalExists() public {
        hoax(users.admin);
        vm.expectRevert(IUpgradeHandler.NoProposalExists.selector);
        vaultFactory.executeUpgrade({ payload: "" });
    }

    function testCannot_ExecuteUpgrade_UpgradeTimeLocked() public {
        startHoax(users.admin);
        vaultFactory.proposeUpgrade({ newImplementation: mockUpgrade });
        vm.expectRevert(IUpgradeHandler.UpgradeTimeLocked.selector);
        vaultFactory.executeUpgrade({ payload: "" });
    }

    function testCannot_UpgradeTo_UUPSUpgradeable() public {
        vm.expectRevert(IUpgradeHandler.UpgradeMethodBlocked.selector);
        vaultFactory.upgradeTo({ newImplementation: address(0) });
    }

    function testCannot_UpgradeToAndCall_UUPSUpgradeable() public {
        vm.expectRevert(IUpgradeHandler.UpgradeMethodBlocked.selector);
        vaultFactory.upgradeToAndCall({ newImplementation: address(0), data: "" });
    }
}
