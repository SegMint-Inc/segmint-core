// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../test/Base.sol";

contract DeployScript is Base {
    uint256 deployerPrivateKey;
    address deployer;

    uint256 adminPrivateKey;
    address admin;

    // uint256 signerPrivateKey;
    // address signer;

    function setUp() public override {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.rememberKey(deployerPrivateKey);

        adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        admin = vm.rememberKey(adminPrivateKey);

        signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        signer = vm.addr(signerPrivateKey);

        vm.createSelectFork({ urlOrAlias: vm.envString("ETH_RPC_URL") });
    }

    function run() public {
        vm.startBroadcast(deployer);

        /// Deploy base registry contracts.
        signerRegistry = new SignerRegistry({ admin_: admin, signer_: signer });
        kycRegistry = new KYCRegistry({ admin_: admin, signerRegistry_: ISignerRegistry(signerRegistry) });
        keys = new Keys({ admin_: admin, uri_: "", kycRegistry_: IKYCRegistry(kycRegistry) });
        keyExchange = new KeyExchange({ admin_: admin, keys_: IKeys(keys), feeReceiver_: FEE_RECEIVER, weth_: WETH });

        /// Deploy implementation addresses for service factory.
        saVault = new SAVault();
        maVault = new MAVault();
        // safeImplementation = new Safe();

        /// Deploy service factory implementation and proxy.
        serviceFactoryImplementation = new ServiceFactory();
        serviceFactoryProxy = new ServiceFactoryProxy({
            implementation_: address(serviceFactoryImplementation),
            payload_: abi.encodeWithSelector(
                ServiceFactory.initialize.selector,
                admin,
                address(maVault),
                address(saVault),
                address(0),
                ISignerRegistry(signerRegistry),
                IKYCRegistry(kycRegistry),
                IKeys(keys)
            )
        });

        /// Proxy the service factory through the service factory proxy.
        serviceFactoryProxied = ServiceFactory(address(serviceFactoryProxy));

        /// Grant service factory the correct role for vault registration.
        keys.grantRoles({ user: address(serviceFactoryProxied), roles: FACTORY_ROLE });

        vm.stopBroadcast();
    }
}
