// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SegMintFactoryTest is Base {
    function setUp() public override {
        super.setUp();
        kycUsers();

        /// Since `factoryProxy` is a proxy, interface the proxy as the implementation contract.
        factory = SegMintFactory(address(factoryProxy));
        keys.grantRoles(address(factory), VAULT_MANAGER_ROLE);
    }

    /* Deployment Test */

    function test_SegMintFactory_Deployment() public {
        assertEq(factory.owner(), address(this));
        assertTrue(factory.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(factory.vaultImplementation(), address(vaultImplementation));
        assertEq(address(factory.signerModule()), address(signerModule));
        assertEq(address(factory.kycRegistry()), address(kycRegistry));
    }

    /* `initialize()` Tests */

    function test_Initialize_UpdatesAsExpected() public {
        SegMintFactory newFactory = new SegMintFactory();
        newFactory.initialize({
            admin_: users.admin,
            vaultImplementation_: address(vaultImplementation),
            vaultSingleImplementation_: address(vaultSingleImplementation),
            safeImplementation_: address(safeImplementation),
            signerModule_: signerModule,
            kycRegistry_: kycRegistry,
            keys_: keys
        });

        assertTrue(newFactory.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(address(newFactory.signerModule()), address(signerModule));
        assertEq(address(newFactory.kycRegistry()), address(kycRegistry));
    }

    function testCannot_Initialize_Initialized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(0x0dc149f0);    // AlreadyInitialized();
        factory.initialize({
            admin_: users.eve,
            vaultImplementation_: address(vaultImplementation),
            vaultSingleImplementation_: address(vaultSingleImplementation),
            safeImplementation_: address(safeImplementation),
            signerModule_: signerModule,
            kycRegistry_: kycRegistry,
            keys_: keys
        });
    }

    /* `createVault()` Tests */

    function test_CreateVault_Restricted() public {
        bytes memory signature = getCreateVaultSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

        hoax(users.alice, users.alice);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: false,
            checkTopic3: false,
            checkData: true,
            emitter: address(factory)
        });
        emit VaultCreated({ user: users.alice, vault: SegMintVault(RANDOM_VAULT) });
        factory.createVault(signature);

        address[] memory userVaults = factory.getVaults({ account: users.alice });
        assertEq(userVaults.length, 1);

        address payable userVault = payable(userVaults[0]);
        assertTrue(keys.isApproved(userVault));

        SegMintVault typedUserVault = SegMintVault(userVault);
        assertEq(typedUserVault.owner(), users.alice);
        assertEq(address(typedUserVault.keys()), address(keys));
    }

    function test_CreateVault_Restricted_Fuzzed(uint256 amount) public {
        amount = bound(amount, 1, 10);

        bytes memory signature = getCreateVaultSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

        startHoax(users.alice, users.alice);
        for (uint256 i = 0; i < amount; i++) {
            vm.expectEmit({
                checkTopic1: true,
                checkTopic2: false,
                checkTopic3: false,
                checkData: true,
                emitter: address(factory)
            });
            emit VaultCreated({ user: users.alice, vault: SegMintVault(RANDOM_VAULT) });
            factory.createVault(signature);
        }
        vm.stopPrank();

        address[] memory userVaults = factory.getVaults({ account: users.alice });
        assertEq(userVaults.length, amount);

        for (uint256 i = 0; i < amount; i++) {
            address payable userVault = payable(userVaults[i]);
            assertTrue(keys.isApproved(userVault));

            SegMintVault typedUserVault = SegMintVault(userVault);
            assertEq(typedUserVault.owner(), users.alice);
            assertEq(address(typedUserVault.keys()), address(keys));
        }
    }

    function test_CreateVault_Unrestricted() public {
        bytes memory signature = getCreateVaultSignature(users.bob, KYCRegistry.AccessType.UNRESTRICTED);

        hoax(users.bob, users.bob);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: false,
            checkTopic3: false,
            checkData: true,
            emitter: address(factory)
        });
        emit VaultCreated({ user: users.bob, vault: SegMintVault(RANDOM_VAULT) });
        factory.createVault(signature);

        address[] memory userVaults = factory.getVaults({ account: users.bob });
        assertEq(userVaults.length, 1);

        address payable userVault = payable(userVaults[0]);
        assertTrue(keys.isApproved(userVault));

        SegMintVault typedUserVault = SegMintVault(userVault);
        assertEq(typedUserVault.owner(), users.bob);
        assertEq(address(typedUserVault.keys()), address(keys));
    }

    function testCannot_CreateVault_InvalidAccessType() public {
        bytes memory signature = getCreateVaultSignature(users.eve, KYCRegistry.AccessType.BLOCKED);

        hoax(users.eve, users.eve);
        vm.expectRevert(Errors.InvalidAccessType.selector);
        factory.createVault(signature);
    }

    function testCannot_CreateVault_SignerMismatch() public {
        bytes memory signature = getCreateVaultSignature(users.bob, KYCRegistry.AccessType.UNRESTRICTED);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.SignerMismatch.selector);
        factory.createVault(signature);
    }

    /* `getVaults()` Tests */

    function test_GetVaults() public {
        address[] memory userVaults = factory.getVaults({ account: users.alice });
        assertEq(userVaults.length, 0);

        bytes memory signature = getCreateVaultSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

        startHoax(users.alice, users.alice);
        for (uint256 i = 0; i < 15; i++) {
            factory.createVault(signature);
            userVaults = factory.getVaults({ account: users.alice });
            assertEq(userVaults.length, i + 1);
        }
        vm.stopPrank();
    }

    /* `proposeUpgrade()` Tests  */

    function test_ProposeUpgrade() public {
        uint40 proposalDeadline = uint40(block.timestamp + UPGRADE_TIME_LOCK);

        hoax(users.admin, users.admin);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(factory)
        });
        emit UpgradeProposed({ admin: users.admin, implementation: address(factory), deadline: proposalDeadline });
        factory.proposeUpgrade(address(factory));

        (address proposedImplementation, uint40 proposedDeadline) = factory.upgradeProposal();
        assertEq(proposedImplementation, address(factory));
        assertEq(proposedDeadline, proposalDeadline);
    }

    function testCannot_ProposeUpgrade_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        factory.proposeUpgrade(address(0));
    }

    function testCannot_ProposeUpgrade_ProposalInProgress() public {
        startHoax(users.admin, users.admin);
        factory.proposeUpgrade(address(factory));

        vm.expectRevert(Errors.ProposalInProgress.selector);
        factory.proposeUpgrade(address(factory));
    }

    /* `cancelUpgrade()` Tests */

    function test_CancelUpgrade() public {
        startHoax(users.admin, users.admin);
        factory.proposeUpgrade(address(factory));

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(factory)
        });
        emit UpgradeCancelled({ admin: users.admin, implementation: address(factory) });
        factory.cancelUpgrade();

        (address proposedImplementation, uint40 proposedDeadline) = factory.upgradeProposal();
        assertEq(proposedImplementation, address(0));
        assertEq(proposedDeadline, 0);
    }

    function testCannot_CancelUpgrade_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        factory.cancelUpgrade();
    }

    function testCannot_CancelUpgrade_NoProposalExists() public {
        hoax(users.admin, users.admin);
        vm.expectRevert(Errors.NoProposalExists.selector);
        factory.cancelUpgrade();
    }

    /* `executeUpgrade()` Tests */

    function test_ExecuteUpgrade() public {
        uint40 proposalDeadline = uint40(block.timestamp + UPGRADE_TIME_LOCK);

        SegMintFactory vaultManagerUpgrade = new SegMintFactory();

        startHoax(users.admin, users.admin);
        factory.proposeUpgrade(address(vaultManagerUpgrade));
        vm.warp(proposalDeadline);
        factory.executeUpgrade("");
    }

    function testCannot_ExecuteUpgrade_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        factory.executeUpgrade("");
    }

    function testCannot_ExecuteUpgrade_NoProposalExists() public {
        hoax(users.admin, users.admin);
        vm.expectRevert(Errors.NoProposalExists.selector);
        factory.executeUpgrade("");
    }

    function testCannot_ExecuteUpgrade_UpgradeTimeLocked() public {
        SegMintFactory vaultManagerUpgrade = new SegMintFactory();

        startHoax(users.admin, users.admin);
        factory.proposeUpgrade(address(vaultManagerUpgrade));

        vm.expectRevert(Errors.UpgradeTimeLocked.selector);
        factory.executeUpgrade("");
    }
}
