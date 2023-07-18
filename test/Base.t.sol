// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";

import {ISegMintKYCRegistry} from "../src/interfaces/ISegMintKYCRegistry.sol";
import {SegMintKYCRegistry} from "../src/SegMintKYCRegistry.sol";

import {Constants} from "./utils/Constants.sol";
import {Events} from "./utils/Events.sol";

import {Users} from "./utils/Types.sol";
import {Errors} from "../src/libraries/Errors.sol";

contract Base is Constants, Events, Test {
    SegMintKYCRegistry public kycRegistry;

    Users public users;

    function setUp() public virtual {
        users = Users({
            admin: createUser("admin"),
            alice: createUser("alice"),
            bob: createUser("bob"),
            eve: createUser("eve")
        });

        kycRegistry = new SegMintKYCRegistry({admin_: users.admin, signer_: SIGNER});
    }

    /* Helper Functions */

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        return user;
    }
}
