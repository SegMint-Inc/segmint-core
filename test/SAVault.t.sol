// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract SAVaultTest is BaseTest {
    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Approve both possible asset types for Alice.
        startHoax(users.alice.account);
        mockERC721.setApprovalForAll({ operator: address(vaultFactory), approved: true });
        mockERC1155.setApprovalForAll({ operator: address(vaultFactory), approved: true });
        vm.stopPrank();
    }

    function testCannot_Initialize_Implementation_SAVault() public {
        Asset memory emptyAsset = Asset({ class: AssetClass.ERC721, token: address(0x01), identifier: 0, amount: 1 });
        vm.expectRevert("Initializable: contract is already initialized");
        saVault.initialize({ _asset: emptyAsset, _keys: keys, _keyAmount: 0, _receiver: users.eve.account, _delegateAsset: false });
    }

    function testCannot_Initialize_SAVault_Keys_ZeroAddressInvalid() public {
        SAVault testVault = new SAVault();
        vm.expectRevert(ISAVault.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVault),
            _data: abi.encodeWithSelector(
                ISAVault.initialize.selector,
                getERC721Asset(),
                address(0),  // Keys
                1,
                users.alice.account,
                false
            )
        });
    }

    function testCannot_Initialize_SAVault_Receiver_ZeroAddressInvalid() public {
        SAVault testVault = new SAVault();
        vm.expectRevert(ISAVault.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVault),
            _data: abi.encodeWithSelector(
                ISAVault.initialize.selector,
                getERC721Asset(),
                keys,
                1,
                address(0),  // Receiver
                false
            )
        });
    }

    function test_UnlockAsset_Fuzzed(uint256 keyAmount, bool isERC721) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());
        Asset memory asset = isERC721 ? getERC721Asset() : getERC1155Asset();

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        startHoax(users.alice.account);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);
        uint256 keyId = newVault.boundKeyId();

        newVault.unlockAsset({ receiver: users.alice.account });
        vm.stopPrank();

        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertTrue(keyConfig.isBurned);
        assertEq(keyConfig.supply, keyAmount);

        Asset memory lockedAsset = newVault.lockedAsset();
        assertEq(lockedAsset.class, AssetClass.NONE);
        assertEq(lockedAsset.token, address(0));
        assertEq(lockedAsset.identifier, 0);
        assertEq(lockedAsset.amount, 0);
    }

    function test_UnlockAsset_ERC721_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());
        Asset memory asset = getERC721Asset();

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        startHoax(users.alice.account);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);
        uint256 keyId = newVault.boundKeyId();

        Asset memory lockedAsset = newVault.lockedAsset();
        assertEq(lockedAsset.class, AssetClass.ERC721);
        assertEq(lockedAsset.token, address(mockERC721));
        assertEq(lockedAsset.identifier, 0);
        assertEq(lockedAsset.amount, 1);

        newVault.unlockAsset({ receiver: users.alice.account });
        vm.stopPrank();

        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertTrue(keyConfig.isBurned);
        assertEq(keyConfig.supply, keyAmount);

        lockedAsset = newVault.lockedAsset();
        assertEq(lockedAsset.class, AssetClass.NONE);
        assertEq(lockedAsset.token, address(0));
        assertEq(lockedAsset.identifier, 0);
        assertEq(lockedAsset.amount, 0);
    }

    function testCannot_UnlockAsset_ZeroAddressInvalid() public {
        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        startHoax(users.alice.account);
        vaultFactory.createSingleAssetVault({ asset: getERC721Asset(), keyAmount: 1, delegateAsset: false, signature: signature });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);

        vm.expectRevert(ISAVault.ZeroAddressInvalid.selector);
        newVault.unlockAsset({ receiver: address(0) });
    }

    function testCannot_UnlockAsset_NoAssetLocked_Fuzzed(uint256 keyAmount, bool isERC721) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());
        Asset memory asset = isERC721 ? getERC721Asset() : getERC1155Asset();

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        startHoax(users.alice.account);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);
        newVault.unlockAsset({ receiver: users.alice.account });

        vm.expectRevert(ISAVault.NoAssetLocked.selector);
        newVault.unlockAsset({ receiver: users.alice.account });
    }

    function testCannot_UnlockAsset_ExceedsBalance_Fuzzed(uint256 keyAmount, bool isERC721) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());
        Asset memory asset = isERC721 ? getERC721Asset() : getERC1155Asset();

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        hoax(users.alice.account);
        vaultFactory.createSingleAssetVault({ asset: asset, keyAmount: keyAmount, delegateAsset: false, signature: signature });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);

        hoax(users.eve.account);
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        newVault.unlockAsset({ receiver: users.eve.account });
    }

    function test_ModifyAssetDelegation() public {
        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        /// Create a new Vault with delegation rights given to Alice.
        hoax(users.alice.account);
        vaultFactory.createSingleAssetVault({
            asset: getERC721Asset(),
            keyAmount: 100,
            delegateAsset: true,
            signature: signature
        });

        ISAVault vault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);

        /// Check outgoing delegations for `vault` and ensure Alice is the only delegate with full rights.
        IDelegateRegistry.Delegation[] memory delegations = delegateRegistry.getOutgoingDelegations(address(vault));
        assertEq(delegations.length, 1);
        assertEq(delegations[0].type_, IDelegateRegistry.DelegationType.ALL);
        assertEq(delegations[0].to, users.alice.account);
        assertEq(delegations[0].from, address(vault));
        assertEq(delegations[0].contract_, address(0));
        assertEq(delegations[0].tokenId, 0);
        assertEq(delegations[0].amount, 0);

        bytes[] memory delegationPayloads = new bytes[](2);

        /// Revoke Alice's delegation rights entirely.
        delegationPayloads[0] = abi.encodeWithSelector(
            IDelegateRegistry.delegateAll.selector,
            users.alice.account,    // `to`
            bytes32(""),            // `rights`
            false                   // `enable`
        );

        /// Approve Bob's delegation rights for all.
        delegationPayloads[1] = abi.encodeWithSelector(
            IDelegateRegistry.delegateAll.selector,
            users.bob.account,  // `to`
            bytes32(""),        // `rights`
            true                // `enable`
        );

        hoax(users.alice.account);
        vault.modifyAssetDelegation(delegationPayloads);

        /// Check outgoing delegations for `vault` and ensure Bob is the only delegate with full rights.
        delegations = delegateRegistry.getOutgoingDelegations(address(vault));
        assertEq(delegations.length, 1);
        assertEq(delegations[0].type_, IDelegateRegistry.DelegationType.ALL);
        assertEq(delegations[0].to, users.bob.account);
        assertEq(delegations[0].from, address(vault));
        assertEq(delegations[0].contract_, address(0));
        assertEq(delegations[0].tokenId, 0);
        assertEq(delegations[0].amount, 0);
    }

    function testCannot_ModifyAssetDelegation_ZeroLengthArray() public {
        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        /// Create a new Vault with delegation rights given to Alice.
        startHoax(users.alice.account);
        vaultFactory.createSingleAssetVault({
            asset: getERC721Asset(),
            keyAmount: 100,
            delegateAsset: true,
            signature: signature
        });

        ISAVault vault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);

        vm.expectRevert(ISAVault.ZeroLengthArray.selector);
        vault.modifyAssetDelegation({ delegationPayloads: new bytes[](0) });
    }

    function testCannot_ModifyAssetDelegation_NoAssetLocked() public {
        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        startHoax(users.alice.account);
        vaultFactory.createSingleAssetVault({
            asset: getERC721Asset(),
            keyAmount: 100,
            delegateAsset: true,
            signature: signature
        });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);
        newVault.unlockAsset({ receiver: users.alice.account });

        vm.expectRevert(ISAVault.NoAssetLocked.selector);
        newVault.modifyAssetDelegation({ delegationPayloads: new bytes[](1) });
    }

    function testCannot_ModifyAssetDelegation_CallerNotVaultCreator_Fuzzed(address notAlice) public {
        vm.assume(notAlice != users.alice.account);

        (, uint256 saNonce) = vaultFactory.getNonces({ account: users.alice.account });
        bytes memory signature = getVaultCreationSignature(users.alice.account, saNonce, VaultType.SINGLE);

        hoax(users.alice.account);
        vaultFactory.createSingleAssetVault({
            asset: getERC721Asset(),
            keyAmount: 100,
            delegateAsset: true,
            signature: signature
        });

        ISAVault newVault = ISAVault(vaultFactory.getSingleAssetVaults({ account: users.alice.account })[0]);

        hoax(notAlice);
        vm.expectRevert(ISAVault.CallerNotVaultCreator.selector);
        newVault.modifyAssetDelegation({ delegationPayloads: new bytes[](1) });
    }
}
