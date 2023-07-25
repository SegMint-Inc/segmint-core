// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../Base.t.sol";

contract SegMintVaultManagerTest is Base {
    function setUp() public override {
        super.setUp();
        kycUsers();

        /// Since `vaultManagerProxy` is a proxy, interface the proxy as the implementation contract.
        vaultManager = SegMintVaultManager(address(vaultManagerProxy));

        hoax(users.admin, users.admin);
        vaultManager.setKeys(ISegMintKeys(address(keys)));

        keys.grantRoles(address(vaultManager), VAULT_MANAGER_ROLE);
    }

    /* Deployment Test */

    function test_SegMintVaultManager_Deployment() public {
        assertEq(vaultManager.owner(), address(this));
        assertTrue(vaultManager.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(vaultManager.vaultImplementation(), address(vaultImplementation));
        assertEq(address(vaultManager.signerModule()), address(signerModule));
        assertEq(address(vaultManager.kycRegistry()), address(kycRegistry));
    }

    /* `initialize()` Tests */

    function test_Initialize_UpdatesAsExpected() public {
        SegMintVaultManager newVaultManager = new SegMintVaultManager();
        newVaultManager.initialize({
            admin_: users.admin,
            vaultImplementation_: address(vaultImplementation),
            signerModule_: signerModule,
            kycRegistry_: kycRegistry
        });

        assertTrue(newVaultManager.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(address(newVaultManager.signerModule()), address(signerModule));
        assertEq(address(newVaultManager.kycRegistry()), address(kycRegistry));
    }

    function testCannot_Initialize_Initialized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert("Initializable: contract is already initialized");
        vaultManager.initialize({
            admin_: users.eve,
            vaultImplementation_: address(vaultImplementation),
            signerModule_: signerModule,
            kycRegistry_: kycRegistry
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
            emitter: address(vaultManager)
        });
        emit VaultCreated({ user: users.alice, vault: SegMintVault(RANDOM_VAULT) });
        vaultManager.createVault(signature);

        address[] memory userVaults = vaultManager.getVaults({ account: users.alice });
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
                emitter: address(vaultManager)
            });
            emit VaultCreated({ user: users.alice, vault: SegMintVault(RANDOM_VAULT) });
            vaultManager.createVault(signature);
        }
        vm.stopPrank();

        address[] memory userVaults = vaultManager.getVaults({ account: users.alice });
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
            emitter: address(vaultManager)
        });
        emit VaultCreated({ user: users.bob, vault: SegMintVault(RANDOM_VAULT) });
        vaultManager.createVault(signature);

        address[] memory userVaults = vaultManager.getVaults({ account: users.bob });
        assertEq(userVaults.length, 1);

        address payable userVault = payable(userVaults[0]);
        assertTrue(keys.isApproved(userVault));

        SegMintVault typedUserVault = SegMintVault(userVault);
        assertEq(typedUserVault.owner(), users.bob);
        assertEq(address(typedUserVault.keys()), address(keys));
    }

    function testCannot_CreateVault_KeysNotSet() public {
        hoax(users.admin, users.admin);
        vaultManager.setKeys(ISegMintKeys(address(0)));

        bytes memory signature = getCreateVaultSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

        hoax(users.eve, users.eve);
        vm.expectRevert(Errors.KeysNotSet.selector);
        vaultManager.createVault(signature);
    }

    function testCannot_CreateVault_InvalidAccessType() public {
        bytes memory signature = getCreateVaultSignature(users.eve, KYCRegistry.AccessType.BLOCKED);

        hoax(users.eve, users.eve);
        vm.expectRevert(Errors.InvalidAccessType.selector);
        vaultManager.createVault(signature);
    }

    function testCannot_CreateVault_SignerMismatch() public {
        bytes memory signature = getCreateVaultSignature(users.bob, KYCRegistry.AccessType.UNRESTRICTED);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.SignerMismatch.selector);
        vaultManager.createVault(signature);
    }

    /* `getVaults()` Tests */

    function test_GetVaults() public {
        address[] memory userVaults = vaultManager.getVaults({ account: users.alice });
        assertEq(userVaults.length, 0);

        bytes memory signature = getCreateVaultSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

        startHoax(users.alice, users.alice);
        for (uint256 i = 0; i < 15; i++) {
            vaultManager.createVault(signature);
            userVaults = vaultManager.getVaults({ account: users.alice });
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
            emitter: address(vaultManager)
        });
        emit UpgradeProposed({ admin: users.admin, implementation: address(vaultManager), deadline: proposalDeadline });
        vaultManager.proposeUpgrade(address(vaultManager));

        (address proposedImplementation, uint40 proposedDeadline) = vaultManager.upgradeProposal();
        assertEq(proposedImplementation, address(vaultManager));
        assertEq(proposedDeadline, proposalDeadline);
    }

    function testCannot_ProposeUpgrade_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultManager.proposeUpgrade(address(0));
    }

    function testCannot_ProposeUpgrade_ProposalInProgress() public {
        startHoax(users.admin, users.admin);
        vaultManager.proposeUpgrade(address(vaultManager));

        vm.expectRevert(Errors.ProposalInProgress.selector);
        vaultManager.proposeUpgrade(address(vaultManager));
    }

    /* `cancelUpgrade()` Tests */

    function test_CancelUpgrade() public {
        startHoax(users.admin, users.admin);
        vaultManager.proposeUpgrade(address(vaultManager));

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(vaultManager)
        });
        emit UpgradeCancelled({ admin: users.admin, implementation: address(vaultManager) });
        vaultManager.cancelUpgrade();

        (address proposedImplementation, uint40 proposedDeadline) = vaultManager.upgradeProposal();
        assertEq(proposedImplementation, address(0));
        assertEq(proposedDeadline, 0);
    }

    function testCannot_CancelUpgrade_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultManager.cancelUpgrade();
    }

    function testCannot_CancelUpgrade_NoProposalExists() public {
        hoax(users.admin, users.admin);
        vm.expectRevert(Errors.NoProposalExists.selector);
        vaultManager.cancelUpgrade();
    }

    /* `executeUpgrade()` Tests */

    function test_ExecuteUpgrade() public {
        uint40 proposalDeadline = uint40(block.timestamp + UPGRADE_TIME_LOCK);

        SegMintVaultManager vaultManagerUpgrade = new SegMintVaultManager();

        startHoax(users.admin, users.admin);
        vaultManager.proposeUpgrade(address(vaultManagerUpgrade));
        vm.warp(proposalDeadline);
        vaultManager.executeUpgrade("");
    }

    function testCannot_ExecuteUpgrade_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultManager.executeUpgrade("");
    }

    function testCannot_ExecuteUpgrade_NoProposalExists() public {
        hoax(users.admin, users.admin);
        vm.expectRevert(Errors.NoProposalExists.selector);
        vaultManager.executeUpgrade("");
    }

    function testCannot_ExecuteUpgrade_UpgradeTimeLocked() public {
        SegMintVaultManager vaultManagerUpgrade = new SegMintVaultManager();

        startHoax(users.admin, users.admin);
        vaultManager.proposeUpgrade(address(vaultManagerUpgrade));

        vm.expectRevert(Errors.UpgradeTimeLocked.selector);
        vaultManager.executeUpgrade("");
    }

    /* `setSignerModule()` Tests */

    function test_SetSignerModule_Fuzzed(address signerModule_) public {
        ISegMintSignerModule oldSignerModule = vaultManager.signerModule();
        ISegMintSignerModule newSignerModule = ISegMintSignerModule(signerModule_);

        hoax(users.admin, users.admin);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(vaultManager)
        });
        emit SignerModuleUpdated({
            admin: users.admin,
            oldSignerModule: oldSignerModule,
            newSignerModule: newSignerModule
        });
        vaultManager.setSignerModule(newSignerModule);

        assertEq(address(vaultManager.signerModule()), address(newSignerModule));
    }

    function testCannot_SetSignerModule_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vaultManager.setSignerModule(ISegMintSignerModule(address(0)));
    }
}
