// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../test/Base.sol";

contract DeployScript is Base {
    uint256 deployerPrivateKey;
    address deployer;

    uint256 adminPrivateKey;
    address admin;

    uint256 signerPrivateKey;
    address signer;

    function setUp() public {
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
        coreSetup({
            admin: admin,
            signer: signer,
            feeReceiver: address(0xFEE5),
            weth: address(0),
            factoryRole: uint256(0xee961466e472802bc53e28ea01e7875c1285a5d1f1992f7b1aafc450304db8bc)
        });
        vm.stopBroadcast();
    }
}
