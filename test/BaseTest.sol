// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockERC721 } from "./mocks/MockERC721.sol";
import { MockERC1155 } from "./mocks/MockERC1155.sol";

import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Users.sol";

abstract contract BaseTest is Base {
    using ECDSA for bytes32;

    /// Constants.
    uint256 public constant ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;
    uint256 public constant FACTORY_ROLE = 0xee961466e472802bc53e28ea01e7875c1285a5d1f1992f7b1aafc450304db8bc;
    address public constant FEE_RECEIVER = address(0xFEE5);
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public signerPrivateKey;
    address public signer;

    /// Define test users.
    Users public users;

    /// Mock token contracts.
    MockERC20 public mockERC20;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    function setUp() public virtual {
        signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        signer = vm.addr(signerPrivateKey);

        createUsers();
        coreSetup({
            admin: users.admin,
            signer: signer,
            feeReceiver: FEE_RECEIVER,
            weth: WETH,
            factoryRole: FACTORY_ROLE
        });
    }

    /// @dev Used to initialize users.
    function createUsers() private {
        users.admin = makeAddr("Admin");

        (users.alice.account, users.alice.privateKey) = makeAddrAndKey("Alice");
        deal({ token: address(mockERC20), to: users.alice.account, give: 1_000_000 ether });
        dealERC721({ token: address(mockERC721), to: users.alice.account, id: 1 });
        dealERC1155({ token: address(mockERC1155), to: users.alice.account, id: 1, give: 5 });

        (users.bob.account, users.bob.privateKey) = makeAddrAndKey("Bob");
        deal({ token: address(mockERC20), to: users.bob.account, give: 1_000_000 ether });
        dealERC721({ token: address(mockERC721), to: users.bob.account, id: 2 });
        dealERC1155({ token: address(mockERC1155), to: users.bob.account, id: 1, give: 5 });

        (users.eve.account, users.eve.privateKey) = makeAddrAndKey("Eve");
        deal({ token: address(mockERC20), to: users.eve.account, give: 1_000_000 ether });
        dealERC721({ token: address(mockERC721), to: users.eve.account, id: 3 });
        dealERC1155({ token: address(mockERC1155), to: users.eve.account, id: 1, give: 5 });
    }

    /// Used for {KYCRegistry.initAccessType}.
    function getAccessSignature(address account, uint256 deadline, IKYCRegistry.AccessType accessType)
        internal
        view
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({
            privateKey: signerPrivateKey,
            digest: keccak256(abi.encodePacked(account, deadline, accessType)).toEthSignedMessageHash()
        });
        return abi.encodePacked(r, s, v);
    }

    /// Used for {ServiceFactory} vault creation functions.
    function getVaultCreateSignature(
        address account,
        IKYCRegistry.AccessType accessType,
        uint256 nonce,
        string memory discriminator
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({
            privateKey: signerPrivateKey,
            digest: keccak256(abi.encodePacked(account, accessType, block.chainid, nonce, discriminator))
                .toEthSignedMessageHash()
        });
        return abi.encodePacked(r, s, v);
    }

}