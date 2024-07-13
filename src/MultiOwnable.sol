// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { FlatBytesLib } from "@rhinestone/flatbytes/src/BytesLib.sol";
import "./SloadLib.sol";

import "forge-std/console2.sol";

/**
 * @title OwnableValidator
 * @dev Module that allows users to designate EOA owners that can validate transactions using a
 * threshold
 * @author Rhinestone
 */
contract MultiChainValidator is ERC7579ValidatorBase {
    using SloadLib for *;
    using FlatBytesLib for *;

    struct Owner {
        address owner;
        uint48 validAfter;
        uint48 validBefore;
    }

    mapping(address account => FlatBytesLib.Bytes) internal owners;

    address immutable L1SELF;

    constructor(address L1Self) {
        if (L1Self == address(0)) {
            L1SELF = address(this);
        } else {
            L1SELF = L1Self;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function getOwnerSlot(address account) public view returns (bytes32 slot) {
        FlatBytesLib.Bytes storage owner = owners[account];
        assembly {
            slot := owner.slot
        }
    }

    /**
     * Initializes the module with the threshold and owners
     * @dev data is encoded as follows: abi.encode(threshold, owners)
     *
     * @param data encoded data containing the threshold and owners
     */
    function onInstall(bytes calldata data) external override {
        if (data.length == 0) return;
        Owner memory owner = abi.decode(data, (Owner));

        FlatBytesLib.Bytes storage $local = owners[msg.sender];
        $local.store(data);
    }

    /**
     * Handles the uninstallation of the module and clears the threshold and owners
     * @dev the data parameter is not used
     */
    function onUninstall(bytes calldata) external override {
        FlatBytesLib.Bytes storage $local = owners[msg.sender];
        $local.clear();
    }

    /**
     * Checks if the module is initialized
     *
     * @param smartAccount address of the smart account
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        bytes32 slot = getOwnerSlot(smartAccount);
        bytes memory value = SloadLib.sload(L1SELF, slot);
        return value.length != 0;
    }

    /**
     * Sets the threshold for the account
     * @dev the function will revert if the module is not initialized
     *
     * @param _threshold uint256 threshold to set
     */
    function setThreshold(uint256 _threshold) external { }

    /**
     * Adds an owner to the account
     * @dev will revert if the owner is already added
     *
     * @param owner address of the owner to add
     */
    function addOwner(Owner calldata owner) external {
        FlatBytesLib.Bytes storage $local = owners[msg.sender];
        $local.store(abi.encode(owner));
    }

    /**
     * Removes an owner from the account
     * @dev will revert if the owner is not added or the previous owner is invalid
     *
     * @param prevOwner address of the previous owner
     * @param owner address of the owner to remove
     */
    function removeOwner(address prevOwner, address owner) external { }

    /**
     * Returns the owners of the account
     *
     * @param account address of the account
     *
     * @return ownersArray array of owners
     */
    function getOwners(address account) external view returns (address[] memory ownersArray) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates a user operation
     *
     * @param userOp PackedUserOperation struct containing the UserOperation
     * @param userOpHash bytes32 hash of the UserOperation
     *
     * @return ValidationData the UserOperation validation result
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        // todo use getSender lib
        bytes32 slot = getOwnerSlot(userOp.sender);
        // sload from L1, fallback if L1 has no data set
        bytes memory value = SloadLib.sload(L1SELF, slot);
        Owner memory signer = abi.decode(value, (Owner));

        address recover = ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature);
        return _packValidationData({
            sigFailed: recover != signer.owner,
            validAfter: signer.validAfter,
            validUntil: signer.validBefore
        });
    }

    /**
     * Validates an ERC-1271 signature with the sender
     *
     * @param hash bytes32 hash of the data
     * @param data bytes data containing the signatures
     *
     * @return bytes4 EIP1271_SUCCESS if the signature is valid, EIP1271_FAILED otherwise
     */
    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    { }

    /**
     * Validates a signature with the data (stateless validation)
     *
     * @param hash bytes32 hash of the data
     * @param signature bytes data containing the signatures
     * @param data bytes data containing the data
     *
     * @return bool true if the signature is valid, false otherwise
     */
    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata data
    )
        external
        view
        returns (bool)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Returns the type of the module
     *
     * @param typeID type of the module
     *
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "OwnableValidatorL1Sload";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
