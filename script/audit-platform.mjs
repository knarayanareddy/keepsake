#!/usr/bin/env node
/**
 * script/audit-platform.mjs — AGENT_MONAD.md and AGENT_BLITZ.md, as assertions.
 *
 * Those two briefs are law in their own domains (chain ids/RPC/gas/logs/Foundry, and submit/live/vote). Prose
 * briefs rot: every one of their "Missing"/"Risk" rows is a property of a file, so each is checked here against
 * the files instead of remembered. Run after touching web/, foundry.toml, script/Deploy.s.sol or the docs.
 *
 *   node script/audit-platform.mjs        # exit 1 with a reason list on any drift
 *
 * It is a floor. It cannot deploy, cannot verify a contract, and cannot tell you whether the room liked it.
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const rd = (p) => { try { return fs.readFileSync(path.join(ROOT, p), "utf8"); } catch { return null; } };
const ui = rd("web/index.html"), world = rd("contracts/World.sol") || "", ftoml = rd("foundry.toml") || "";
const deploy = rd("script/Deploy.s.sol") || "", readme = rd("README.md") || "", sub = rd("SUBMISSION.md") || "";
const skills = rd(".monskills.json");

const fail = [], warn = [];
const ok = (cond, id, msg, soft = false) => {
  if (cond) console.log(`  ✓ ${id} — ${msg}`);
  else (soft ? warn : fail).push(`${id} — ${msg}`), console.log(`  ${soft ? "·" : "✗"} ${id} — ${msg}`);
};

console.log("AGENT_MONAD §0 — which chain");
ok(/wallet_addEthereumChain/.test(ui || ""), "addEthereumChain", "the UI offers the network itself, one prompt, no docs-reading");
const params = (ui || "").match(/const MONAD_PARAMS = \{([\s\S]*?)\n    \};/);
const want = {
  chainId: "0x279f", chainName: "Monad Testnet", rpc: "https://testnet-rpc.monad.xyz", explorer: "https://testnet.monadvision.com",
};
ok(params && params[1].includes(`"${want.chainId}"`) === false && params[1].includes(`chainId: MONAD_CHAIN`) &&
   params[1].includes(want.chainName) && params[1].includes(want.rpc) && params[1].includes(want.explorer) &&
   /decimals: 18/.test(params[1]) && /symbol: "MON"/.test(params[1]),
  "§8 payload", "MONAD_PARAMS matches the brief's copy-paste block exactly (0x279f · MON · testnet rpc · MonadVision)");
ok(/MONAD_CHAIN = "0x279f"/.test(ui || "") && /10143/.test(ui || ""), "chain id pinned", "10143 / 0x279f both present");
ok(!/mainnet.*faucet|143.*faucet/i.test(ui || ""), "no mainnet temptation", "nothing asks for real MON");

console.log("\nAGENT_MONAD §1 — gas is the limit, not the usage");
const caps = (ui || "").match(/const GAS_CAP = \{([^}]+)\}/);
ok(!!caps, "GAS_CAP exists", "per-verb limits are set in code, not left to the wallet");
const verbs = [...new Set([...(ui || "").matchAll(/fire\(\s*[^,]+,\s*"(\w+)"/g)].map((m) => m[1]))];
const uncapped = verbs.filter((v) => caps && !new RegExp(`\\b${v}:`).test(caps[1]));
ok(verbs.length > 0 && uncapped.length === 0, "every verb capped", `${verbs.join(", ")}${uncapped.length ? " — uncapped: " + uncapped.join(", ") : ""}`);
if (caps) {
  const nums = [...caps[1].matchAll(/(\w+):\s*([\d_]+)/g)].map((m) => [m[1], Number(m[2].replace(/_/g, ""))]);
  const loose = nums.filter(([, n]) => n > 2_000_000);
  ok(nums.every(([, n]) => n >= 40_000), "caps are not under the real cost", "smallest cap ≥ 40,000 (a pact costs 338,508 cold)");
  ok(loose.length === 0, "caps are tight", loose.length ? `${loose.map(([k, n]) => k + "=" + n).join(", ")} looks like a pad` : `max ${Math.max(...nums.map((n) => n[1])).toLocaleString()}`);
  // and they must be derived from the recording, not invented
  const demo = rd("web/demo-match.json");
  if (demo) {
    const worst = Math.max(...JSON.parse(demo).frames.filter((f) => f.gas).map((f) => f.gas));
    const pactCap = Number((caps[1].match(/pact:\s*([\d_]+)/) || [])[1]?.replace(/_/g, "") ?? 0);
    ok(pactCap >= worst && pactCap <= worst * 1.6, "cap ⊂ measured + headroom", `worst recorded verb is ${worst.toLocaleString()} gas, pact cap ${pactCap.toLocaleString()}`);
  }
}

console.log("\nAGENT_MONAD §2 — RPC, logs, nonces");
ok(/JsonRpcProvider\(MONAD_RPC\)/.test(ui || "") && /MONAD_RPC = "https:\/\/testnet-rpc\.monad\.xyz"/.test(ui || ""),
  "public read RPC", "spectating does not need a wallet, a CDN, or localhost");
ok(!/localhost|127\.0\.0\.1/.test((ui || "").replace(/\/\*[\s\S]*?\*\//g, "")), "no localhost anywhere in web/",
  "a voter's phone and the deployed page agree");
const wide = ((ui || "").match(/latest - (\d+)/g) || []).map((m) => Number(m.split(" - ")[1]));
ok(wide.length > 0 && wide.every((n) => n <= 1000), "log window bounded",
  `fallback back-fill is ${Math.max(...wide, 0)} blocks (docs cap eth_getLogs ranges near 1000; the deploy block widens it)`);
ok(/catch \(e1\)[\s\S]{0,240}queryFilter/.test(ui || ""), "refused range is retried narrow", "a rejected wide scan degrades to the last window instead of killing the board");
ok(!/newPendingTransactions|eth_subscribe/.test(ui || ""), "no mempool theatre", "pending-tx subs do not exist on Monad; nothing here pretends they do");
ok(!/\.send\(\s*\[/.test(ui || ""), "no JSON-RPC batches", "some endpoints serve batch size 1");
const fireBody = ((ui || "").match(/async function fire\([\s\S]*?\n    \}/) || [""])[0];
const lockAt = fireBody.indexOf("inflight = label"), finAt = fireBody.indexOf("} finally {"), relAt = fireBody.indexOf("inflight = null");
ok(lockAt >= 0 && finAt > lockAt && relAt > finAt, "one write per wallet",
  "lock taken before the try, released in finally — a throw inside fire() cannot wedge the board");
ok(/await tx\.wait\(\)/.test(ui || ""), "receipt awaited", "no verb is issued against an unbuilt nonce chain");
const ivs = [...(ui || "").matchAll(/pollingInterval = (\d+)|setInterval\([\s\S]{0,120}?, (\d+)\)/g)].map((m) => Number(m[1] ?? m[2])).filter(Boolean);
ok(ivs.length > 0 && ivs.every((n) => n >= 1200), "polling is polite", `intervals ${ivs.join("/")} ms against a 20–50 rps endpoint`);
ok(!/, "latest"\)/.test(ui || "") || !/viewPlayer\([^)]*\{\s*blockTag/.test(ui || ""), "no historical calls", "state is read at latest; some RPCs do not serve old blocks");

console.log("\nAGENT_MONAD §1/§4 — contract properties we must not 'fix'");
ok(/block\.number, block\.prevrandao/.test(world) && !/block\.timestamp/.test(world),
  "match identity is not timestamp-based", "second-granularity TIMESTAMP would collide across 3–4 blocks; block.number + prevrandao does not");
ok(/startedAt: uint64\(block\.number\)/.test(world), "startedAt is a height", "not a clock the sequencer can drift");

console.log("\nAGENT_MONAD §3 — Foundry");
ok(/\[rpc_endpoints\][\s\S]*monad_testnet = "https:\/\/testnet-rpc\.monad\.xyz"/.test(ftoml), "rpc_endpoints", "monad_testnet resolves for --rpc-url monad_testnet");
ok(/monad_mainnet = "https:\/\/rpc\.monad\.xyz"/.test(ftoml), "mainnet alias", "present but not the default anywhere");
ok(/\[etherscan\][\s\S]*monad_testnet = \{[^}]*chain = 10143[^}]*\}/.test(ftoml), "[etherscan]", "MonadVision wired for --verify, key \"-\"");
ok(/solc = "0\.8\.24"/.test(ftoml) && /evm_version = "shanghai"/.test(ftoml), "toolchain pinned", "0.8.24 / shanghai, the numbers in DEEPDIVE are for this");
ok(/--legacy/.test(deploy) && /--gas-estimate-multiplier 120/.test(deploy), "deploy flags documented", "the script's own header carries the flags that matter");
ok(/fs_permissions = \[\{ access = "read-write", path = "\.\/web" \}\]/.test(ftoml), "fs_permissions", "Deploy.s.sol can write web/addresses.json");

console.log("\nAGENT_BLITZ §3 P0/P1 — what a vote depends on");
const liveRow = (sub.match(/\|\s*\*\*Live\*\*\s*\|([^\n]*)/) || [])[1] || "";
const liveUrl = (liveRow.match(/`([^`]+)`/) || [])[1] || liveRow.trim();
ok(/^https:\/\//.test(liveUrl) && !/localhost|127\.0\.0\.1/.test(liveUrl), "Live is not localhost",
  `the card's Live field is ${liveUrl.slice(0, 46)} — https, no loopback${/TODO|<user>/.test(liveUrl) ? " (placeholder until deploy)" : ""}`);
ok(/Try it in 60 seconds/.test(readme) && /Watch/.test(readme), "README 60-second path", "connect → spawn → watch → adjacent → pact → verify");
ok(/Live:`[^`]*TODO|Live: `https:\/\/TODO`/.test(readme), "README has the address slots", "three TODOs a deploy has to fill — visible, not buried");
ok(/never `http:\/\/localhost`/.test(sub) || /never localhost/.test(sub), "localhost warned", "the sheet says out loud that a dead link loses votes");
ok(/claim (your )?testnet MON|MON claim|in-app claim/i.test(sub + readme), "MON from the event", "the platform's own claim is the funded-wallet path, not only the public faucet");
ok(/verify-contract|--verify/.test(sub) && /MonadVision|monadvision/.test(sub + readme), "source verification planned", "an unverified World reads as amateur on a peer-voted card");
ok(/You cannot attest yourself|cannot certify yourself/i.test(readme), "differentiator stated", "no self-attestation is the sentence, not a feature list");
ok(!/10,?000 TPS|10k TPS/i.test(readme + sub), "no borrowed TPS claim", "the pitch says 303 ms measured / ~600 ms finality, not the marketing number");
if (skills) {
  const j = JSON.parse(skills);
  const n = (j.networks_used || [])[0] || {};
  ok(n.chain_id === 10143 && n.rpc === "https://testnet-rpc.monad.xyz", ".monskills.json agrees", "one chain id across the repo, checked mechanically");
} else warn.push(".monskills.json — missing (the ecosystem brief asks for networks-used metadata)");
const addrs = rd("web/addresses.json");
if (addrs) {
  const j = JSON.parse(addrs);
  ok(/^0x[0-9a-fA-F]{40}$/.test(j.world || "") && /^0x[0-9a-fA-F]{40}$/.test(j.log || "") && Number(j.block) > 0,
    "addresses.json is real", `world/log/block = ${j.world}/${j.log}/${j.block}`);
  const rm = (readme.match(/World: `(0x[0-9a-fA-F]{40}|0xTODO)`/) || [])[1] || "", rl = (readme.match(/HonorLog: `(0x[0-9a-fA-F]{40}|0xTODO)`/) || [])[1] || "";
  ok(rm === j.world && rl === j.log, "README and addresses.json agree", "the card and the config cannot diverge silently");
} else {
  warn.push("web/addresses.json — absent: expected before the deploy, and the UI falls back to preview mode");
}

console.log(fail.length ? `\n✗ ${fail.length} platform-brief violation${fail.length > 1 ? "s" : ""}:\n  ${fail.join("\n  ")}` : "\n✓ every checked clause of AGENT_MONAD/AGENT_BLITZ holds");
if (warn.length) console.log(`  · ${warn.length} note${warn.length > 1 ? "s" : ""}: ${warn.join(" · ")}`);
console.log(`  ${fail.length ? "failing" : "clean"} · warnings ${warn.length}`);
process.exitCode = fail.length ? 1 : 0;
