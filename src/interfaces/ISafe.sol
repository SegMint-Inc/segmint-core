// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title ISafe
 * @notice N/A
 */

interface ISafe {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to initialize a safe with zero signers.
     */
    error ZeroSignerAmount();

    /**
     * Thrown when trying to initialize a safe with more than the maximum number of signers.
     */
    error OverMaxSigners();

    /**
     * Thrown when trying to unlock a zero amount of assets.
     */
    error ZeroAssetAmount();

    /**
     * Thrown when trying to unlock an amount of assets that exceeds the movement limit in one transaction.
     */
    error OverMovementLimit();

    /**
     * Thrown when the caller is not an approved signer.
     */
    error CallerNotSigner();

    /**
     * Thrown when a native token unlock transfer fails.
     */
    error NativeTokenUnlockFailed();

    /**
     * Thrown when trying to unlock an asset of class `NONE`.
     */
    error NoneAssetType();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the types of assets that can be stored in a multi-asset vault.
     */
    enum SafeAssetClass {
        NONE,
        ERC20,
        ERC721,
        ERC1155
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating the parameters for asset unlocking.
     * @param class Enum defining the class of the asset.
     * @param token Contract address of the asset.
     * @param identifier Unique token identifier.
     * @param amount The amount of the asset being locked.
     * @dev For ERC721 tokens, the `amount` should always be 1.
     */
    struct SafeAsset {
        SafeAssetClass class;
        address token;
        uint256 identifier;
        uint256 amount;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialize a safe.
     * @param signers_ List of intended signers to initialize the safe with.
     * @param quorumValue_ Number of approvals required to reach quorum.
     */
    function initialize(address[] calldata signers_, uint256 quorumValue_) external;
}
