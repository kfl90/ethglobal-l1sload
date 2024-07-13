// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "src/utils/MockSload.sol";
import { Test } from "forge-std/Test.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { MultiChainValidator } from "src/MultiOwnable.sol";

import "src/utils/MockL1Block.sol";
import "src/utils/MockSload.sol";
import "src/SloadLib.sol";

contract MulitChainTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    MultiChainValidator internal validator;

    L1Blocks internal l1Blocks;
    L1Sload internal l1Sload;

    Account internal signer;

    function setUp() public {
        init();

        l1Blocks = new L1Blocks();
        l1Sload = new L1Sload();
        vm.etch(L1SLOAD_PRECOMPILE, address(l1Sload).code);
        vm.etch(L1BLOCKS_PRECOMPILE, address(l1Blocks).code);
        signer = makeAccount("signer");

        l1Blocks = L1Blocks(L1BLOCKS_PRECOMPILE);
        l1Sload = L1Sload(L1SLOAD_PRECOMPILE);

        // Create the validator
        validator = new MultiChainValidator(address(0));
        vm.label(address(validator), "MultiChainValidator");

        // Create the account and install the validator
        instance = makeAccountInstance("S1SloadAccount");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });
    }

    function testExec() public {
        bytes32 slot = validator.getOwnerSlot(instance.account);
        l1Sload.set(
            address(validator),
            slot,
            abi.encode(
                MultiChainValidator.Owner({ owner: signer.addr, validAfter: 0, validBefore: 0 })
            )
        );
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Get the UserOp data (UserOperation and UserOperationHash)
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });

        // Set the signature
        userOpData.userOp.signature = signHash(signer.key, userOpData.userOpHash);

        // Execute the UserOpprivKey
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }

    function test_withLocalSigner() public {
        testExec();

        Account memory signer2 = makeAccount("signer2");

        vm.prank(instance.account);
        validator.addOwner(
            MultiChainValidator.Owner({ owner: signer2.addr, validAfter: 0, validBefore: 0 })
        );

        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Get the UserOp data (UserOperation and UserOperationHash)
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });

        // Set the signature
        userOpData.userOp.signature = signHash(signer2.key, userOpData.userOpHash);

        // Execute the UserOpprivKey
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }

    function signHash(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ECDSA.toEthSignedMessageHash(digest));

        // Sanity checks
        address _signer = ecrecover(ECDSA.toEthSignedMessageHash(digest), v, r, s);
        require(_signer == vm.addr(privKey), "Invalid signature");

        return abi.encodePacked(r, s, v);
    }
}
