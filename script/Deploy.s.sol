// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { MultiChainValidator } from "src/MultiOwnable.sol";

/**
 * @title Deploy
 * @author @kopy-kat
 */
contract DeployScript is Script {
    function run() public {
        bytes32 salt = bytes32(uint256(0));

        vm.startBroadcast(vm.envUint("PK"));

        // vm.createSelectFork("sepolia");
        new MultiChainValidator{ salt: salt }(address(0));
        // vm.createSelectFork("scroll-devnet");
        // new MultiChainValidator{ salt: salt }(address(0));

        vm.stopBroadcast();
    }
}
