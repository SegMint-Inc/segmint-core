// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../test/Base.sol";

contract DeployScript is Base {
    using stdJson for string;

    uint256 public deployerPrivateKey;
    address public deployer;

    address public signer;
    address public admin;
    address public feeReceiver;
    address public weth;

    function setUp() public {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.rememberKey(deployerPrivateKey);

        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");
        string memory path = string.concat(basePath, vm.envString("CONSTANTS_FILENAME"));
        string memory jsonConstants = vm.readFile(path);

        signer = abi.decode(vm.parseJson(jsonConstants, ".signer"), (address));
        admin = abi.decode(vm.parseJson(jsonConstants, ".admin"), (address));
        feeReceiver = abi.decode(vm.parseJson(jsonConstants, ".feeReceiver"), (address));
        weth = abi.decode(vm.parseJson(jsonConstants, ".wrappedEther"), (address));
    }

    function run() public {
        vm.startBroadcast(deployer);
        coreSetup({ admin: admin, signer: signer, feeReceiver: feeReceiver, weth: weth });
        vm.stopBroadcast();
    }
}
