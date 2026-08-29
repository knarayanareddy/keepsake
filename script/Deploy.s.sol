// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HonorLog} from "../contracts/HonorLog.sol";
import {World} from "../contracts/World.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        HonorLog log = new HonorLog();
        World world = new World(log);
        log.setWorld(address(world));
        vm.stopBroadcast();
        console.log("HonorLog", address(log));
        console.log("World   ", address(world));
    }
}
