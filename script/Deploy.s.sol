// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HonorLog} from "../contracts/HonorLog.sol";
import {World} from "../contracts/World.sol";

/// Deploys the pair and pins the attester, in the one order that works:
/// HonorLog -> World(log) -> setWorld(world). Skipping `setWorld` makes every
/// `attest` revert NotWorld, i.e. a silently dead demo.
///
///   forge install foundry-rs/forge-std          # once; the repo ships no lib/
///   export PRIVATE_KEY=0x…            # foundry reads this env var; no --private-key flag needed
///   forge script script/Deploy.s.sol:Deploy --rpc-url monad_testnet --broadcast \
///     --legacy --gas-estimate-multiplier 120 --verify
///
/// `--legacy` because 1559 estimation is flaky on the testnet endpoint; the multiplier is the only
/// padding to use, since Monad charges gas_limit and a wallet pads on its own. `--verify` resolves
/// [etherscan] monad_testnet in foundry.toml (MonadVision) — an unverified World reads as amateur on a
/// peer-voted card. Chain id must be 10143, the network the event's MON claim funds (AGENT_MONAD §0).
contract Deploy is Script {
    function run() external {
        uint256 deployBlock = block.number; // UI event-scan start; one block early is harmless

        vm.startBroadcast();
        HonorLog log = new HonorLog();
        World world = new World(log);
        log.setWorld(address(world)); // write-once — see HonorLog.WorldAlreadySet
        vm.stopBroadcast();

        console.log("HonorLog", address(log));
        console.log("World", address(world));

        // So the UI needs no copy/paste at the projector (needs fs_permissions in foundry.toml).
        string memory json = string.concat(
            '{\n  "world": "', vm.toString(address(world)),
            '",\n  "log": "', vm.toString(address(log)),
            '",\n  "block": ', vm.toString(deployBlock + 1),
            "\n}\n"
        );
        vm.writeFile("web/addresses.json", json);

        console.log("UI: web/index.html?world=%s&log=%s", address(world), address(log));
    }
}
