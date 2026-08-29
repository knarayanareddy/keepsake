#!/usr/bin/env node
// Regenerates web/demo-match.json — the frame track the page plays when no World is wired up
// (see README "Demo modes", SUBMISSION.md §5). It is not a mock: it compiles the contracts in
// ../contracts and executes a full demo match against that bytecode in a local EVM, then
// serialises the state after every transaction. Coordinates, hp, ammo, UIDs and gas are read
// back out of the EVM, so if a rule changes, the recording changes with it.
//
//   npm --prefix /tmp/probe init -y && npm --prefix /tmp/probe i \
//       solc@0.8.24 viem @ethereumjs/vm@7 @ethereumjs/common@4 @ethereumjs/block@5 \
//       @ethereumjs/tx@5 @ethereumjs/util@9 @ethereumjs/statemanager
//   NODE_PATH=/tmp/probe/node_modules node script/record-demo.js     # deterministic: same frames
//
// (The deps stay outside the repo on purpose: this is provenance tooling, not app runtime. The
// sibling verification probes — evm.js, verify-fixes.js, uismoke.mjs — live in
// /home/user/keepsake-probe and are described in ../DEEPDIVE.md Appendix B.)
// Records a full demo match against the REAL patched bytecode in a local EVM and writes
// web/demo-match.json — the frame track the UI plays back when no World is wired up.
// Nothing in the file is invented: coordinates, hp, ammo, UIDs and gas are whatever the
// contracts actually produced on this run.
const fs = require("fs"), path = require("path");
const solc = require("solc");
const { VM } = require("@ethereumjs/vm");
const { Common, Chain, Hardfork } = require("@ethereumjs/common");
const { Block } = require("@ethereumjs/block");
const { Account, Address, privateToAddress, bytesToHex, generateAddress } = require("@ethereumjs/util");
const { encodeFunctionData, decodeFunctionResult, toBytes } = require("viem");
const TX = require("@ethereumjs/tx");
const mkTx = TX.createLegacyTx ?? ((p, o) => TX.TransactionFactory.fromTxData({ type: 0, ...p }, o));

const SRC = path.join(__dirname, "..", "contracts");
const OUT = path.join(__dirname, "..", "web", "demo-match.json");
const KIND_NAME = ["", "PACT", "SPARE", "BETRAYAL", "CONDUCT"];

function compile() {
  const sources = {};
  for (const f of fs.readdirSync(SRC)) if (f.endsWith(".sol")) sources[f] = { content: fs.readFileSync(path.join(SRC, f), "utf8") };
  const input = {
    language: "Solidity", sources,
    settings: {
      optimizer: { enabled: true, runs: 200 }, evmVersion: "shanghai",
      outputSelection: { "*": { "*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object"] } },
    },
  };
  const out = JSON.parse(solc.compile(JSON.stringify(input)));
  const errs = (out.errors || []).filter((e) => e.severity === "error");
  if (errs.length) { console.log(errs.map((e) => e.formattedMessage).join("\n")); process.exit(1); }
  const pick = (n) => {
    const f = Object.keys(out.contracts).find(k => out.contracts[k][n]);
    return { abi: out.contracts[f][n].abi, code: out.contracts[f][n].evm.bytecode.object, runtime: out.contracts[f][n].evm.deployedBytecode.object.length / 2 };
  };
  return { World: pick("World"), HonorLog: pick("HonorLog"), settings: "solc 0.8.24 · evm shanghai · optimizer runs 200" };
}

const PK = { deployer: "0x" + "11".repeat(32), alice: "0x" + "22".repeat(32), bob: "0x" + "33".repeat(32) };
const toB = (h) => toBytes(h.startsWith("0x") ? h : "0x" + h);
const addrOf = (pk) => new Address(privateToAddress(toB(pk)));
const hex = (a) => bytesToHex(a.bytes ? a.bytes : a);

let blockNum = 1n, cur = null;
const nonce = new Map();

async function main() {
  const C = compile();
  const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.Shanghai });
  const vm = await VM.create({ common, allowUnlimitedContractSize: true });
  await vm.init();

  async function advance() {
    blockNum += 1n;
    cur = await Block.fromBlockData({
      header: {
        number: blockNum, gasLimit: 30000000n, difficulty: 0n,
        timestamp: BigInt(1756000000) + blockNum,
        prevRandao: toB("0x" + blockNum.toString(16).padStart(64, "0")),
      },
    }, { common });
    vm.block = cur;
  }
  async function send(pk, to, data) {
    const from = addrOf(pk); await advance();
    const n = nonce.get(hex(from)) ?? 0; nonce.set(hex(from), n + 1);
    const acc = (await vm.stateManager.getAccount(from)) ?? new Account();
    acc.balance = 10n ** 22n; await vm.stateManager.putAccount(from, acc);
    const tx = mkTx({ chainId: 1, nonce: n, gasLimit: 8000000n, gasPrice: 1000000000n, to, data, value: 0n }, { common }).sign(toB(pk));
    try {
      const r = await vm.runTx({ tx, block: cur, skipNonce: true, skipBalance: true });
      if (r.execResult.exceptionError) return { ok: false, gas: 0, sel: "0x" + Buffer.from(r.execResult.returnValue).toString("hex").slice(0, 10) };
      const ca = r.createdAddress ? hex(r.createdAddress) : (!to ? "0x" + Buffer.from(generateAddress(from.bytes, BigInt(n))).toString("hex") : null);
      return { ok: true, createdAddress: ca, gas: Number(r.execResult.executionGasUsed ?? 0) };
    } catch (e) { return { ok: false, gas: 0, err: e.message }; }
  }
  const W = C.World.abi, L = C.HonorLog.abi;
  let WORLD, LOG;
  async function call(to, abi, fn, args = []) {
    const r = await vm.evm.runCall({
      to: new Address(toBytes(to)),
      data: toBytes(encodeFunctionData({ abi, functionName: fn, args })),
      gasLimit: 10000000n, isStatic: true,
    });
    if (r.execResult.exceptionError) throw new Error(`${fn} reverted`);
    return decodeFunctionResult({ abi, functionName: fn, data: "0x" + Buffer.from(r.execResult.returnValue).toString("hex") });
  }
  const at = (to, abi, fn, args, pk) => send(pk, new Address(toBytes(to)), toBytes(encodeFunctionData({ abi, functionName: fn, args })));
  const world = (fn, args, pk) => at(WORLD, W, fn, args ?? [], pk);
  const view = (who) => call(WORLD, W, "viewPlayer", [hex(who)]);
  const snap = (p) => ({
    x: Number(p.x), y: Number(p.y), hp: Number(p.hp), ammo: Number(p.ammo),
    alive: !!p.alive, joined: !!p.joined,
    kept: Number(p.pactKept), broke: Number(p.pactBroken), spared: Number(p.spared),
  });
  const factCount = (who) => call(LOG, L, "countOf", [hex(who)]).then(Number);
  const newestFact = async (who) => {
    const n = await factCount(who);
    if (!n) return null;
    const uid = await call(LOG, L, "uidAt", [hex(who), BigInt(n - 1)]);
    const a = await call(LOG, L, "get", [uid]);
    return { kind: Number(a.kind), uid, other: (a.other || "").toLowerCase(), refUID: a.refUID, extra: Number(a.extra) };
  };

  // ── deploy exactly the way script/Deploy.s.sol does ──
  LOG = (await send(PK.deployer, null, toB(C.HonorLog.code))).createdAddress;
  WORLD = (await send(PK.deployer, null, toB(C.World.code + LOG.slice(2).padStart(64, "0")))).createdAddress;
  if (!(await at(LOG, L, "setWorld", [WORLD], PK.deployer)).ok) throw new Error("setWorld failed");
  console.log(`deployed  HonorLog ${LOG}\n          World    ${WORLD}`);

  const A = addrOf(PK.alice), B = addrOf(PK.bob);
  const aKey = hex(A).toLowerCase(), bKey = hex(B).toLowerCase();
  const NAMES = { [aKey]: "ALICE", [bKey]: "BOB" };
  const frames = [];
  const prevCount = { [aKey]: 0, [bKey]: 0 };

  async function push(actorAddr, verb, text, gas) {
    const [pa, pb] = [await view(A), await view(B)];
    let fact = null;
    if (actorAddr && prevCount[actorAddr] !== undefined) {
      const who = actorAddr === aKey ? A : B;
      const n = await factCount(who);
      if (n > prevCount[actorAddr]) fact = await newestFact(who);
      prevCount[actorAddr] = n;
    }
    frames.push({
      i: frames.length,
      actor: NAMES[actorAddr] || "WORLD",
      actorAddr: actorAddr || null,
      verb, text, gas: gas || 0, block: Number(blockNum),
      state: { [aKey]: snap(pa), [bKey]: snap(pb) },
      fact: fact ? { kind: fact.kind, kindName: KIND_NAME[fact.kind], uid: fact.uid, other: fact.other, refUID: fact.refUID, extra: fact.extra } : null,
    });
    console.log(`  frame ${String(frames.length - 1).padStart(2)}  b${blockNum}  ${verb.padEnd(6)} ${text}${fact ? `   [${KIND_NAME[fact.kind]} ${fact.uid.slice(0, 16)}… · gas ${gas}]` : ""}`);
  }
  async function act(pk, fn, args, verb, textFn) {
    const who = pk === PK.alice ? A : B;
    const r = await world(fn, args, pk);
    if (!r.ok) throw new Error(`${verb} reverted ${r.sel || r.err}`);
    await push(hex(who).toLowerCase(), verb, await textFn(), r.gas);
    return r;
  }

  const sm = await world("startMatch", [], PK.deployer);
  await push(null, "startMatch", `the World opens a match — nobody chooses the board, the deployer rotates it`, sm.gas);

  await act(PK.alice, "spawn", [], "spawn", async () => { const p = await view(A); return `ALICE spawns at (${p.x},${p.y}) — ${p.hp} hp, ${p.ammo} rounds, coordinates from block entropy`; });
  await act(PK.bob, "spawn", [], "spawn", async () => { const p = await view(B); return `BOB spawns at (${p.x},${p.y}) — ${p.hp} hp, ${p.ammo} rounds`; /* first contact */; });

  async function approach(pk, otherPk, name) {
    for (let i = 0; i < 40; i++) {
      const v = await view(otherPk), p = await view(pk === PK.alice ? A : B);
      const rx = Number(v.x) - Number(p.x), ry = Number(v.y) - Number(p.y);
      if (Math.max(Math.abs(rx), Math.abs(ry)) <= 1) return;          // already adjacent
      const dx = Math.sign(rx), dy = Math.sign(ry);
      const r = await world("move", [dx, dy], pk);
      if (!r.ok) { console.log(`    ! move(${dx},${dy}) reverted ${r.sel || r.err} from (${p.x},${p.y}) toward (${v.x},${v.y})`); return; }
      const p2 = await view(pk === PK.alice ? A : B);
      await push(hex(pk === PK.alice ? A : B).toLowerCase(), "move", `${name} steps to (${p2.x},${p2.y}) — 1 cell per tx, Chebyshev`, r.gas);
    }
  }
  await approach(PK.alice, B, "ALICE");
  await approach(PK.bob, A, "BOB");
  { const qa = await view(A), qb = await view(B);
    console.log(`  adjacency check: ALICE(${qa.x},${qa.y}) BOB(${qb.x},${qb.y}) cheb=${Math.max(Math.abs(Number(qa.x)-Number(qb.x)), Math.abs(Number(qa.y)-Number(qb.y)))}`); }

  for (let i = 0; i < 3; i++)
    await act(PK.alice, "shoot", [hex(B)], "shoot", async () => { const p = await view(B); return `ALICE shoots BOB → ${p.hp} hp${p.hp <= 2 ? " · inside the spare window" : ""}`; });
  for (let i = 0; i < 2; i++)
    await act(PK.bob, "shoot", [hex(A)], "shoot", async () => { const p = await view(A); return `BOB answers → ALICE at ${p.hp} hp`; });

  await act(PK.alice, "pact", [hex(B)], "pact", async () => "ALICE offers a pact: I will not finish you. One-way, no acceptance path");
  await act(PK.alice, "spare", [hex(B)], "spare", async () => "ALICE spares BOB — the kill shot was real (2 hp, still armed) so the chain mints it");
  await act(PK.alice, "shoot", [hex(B)], "shoot", async () => { const p = await view(B); return `ALICE shoots anyway → ${p.hp} hp. Betrayal: refUID points at her own pact`; });
  await act(PK.alice, "sealMe", [], "seal", async () => { const p = await view(A); return `ALICE seals her conduct — ${p.pactKept} kept, ${p.spared} spared, ${p.pactBroken} broken, a score the chain computes, not the player`; });
  // rotate the match and prove what survives it
  const betrayalUid = frames.filter(f => f.fact && f.fact.kind === 3).map(f => f.fact.uid).pop();
  const before = await factCount(A);
  const sm2 = await world("startMatch", [], PK.deployer);
  void sm2;
  await act(PK.bob, "spawn", [], "spawn", async () => { const p = await view(B); return `a NEW match: BOB re-enters at (${p.x},${p.y}) — ${p.hp} hp, score reset to ${p.pactKept}/${p.spared}/${p.pactBroken}`; });
  const v = await call(LOG, L, "verify", [betrayalUid]);
  await push(bKey, "verify", `the board forgot everything; the log did not — ${before} records still resolve for ALICE, and verify(betrayal) still returns ok=${v[0]} attester=${v[2].toLowerCase() === WORLD.toLowerCase() ? "the World" : "??"} kind=${KIND_NAME[Number(v[5])]}`, 0);
  frames[frames.length - 1].state = frames[frames.length - 2].state;

  const pa = await view(A), pb = await view(B);
  const score = Number(pa.pactKept) + Number(pa.spared) * 2 - Number(pa.pactBroken) * 3;
  const totalGas = frames.reduce((s, f) => s + f.gas, 0);
  const doc = {
    meta: {
      what: "A recorded match, replayed by the page when no World contract is wired. Same source, same compiler settings, executed against the actual patched bytecode.",
      honest_warning: "LOCAL EVM RECORDING, NOT A TESTNET BROADCAST. The UIDs below exist in this trace only. Run script/Deploy.s.sol and web/addresses.json appears next to this file, and the page uses live chain data instead.",
      generated: new Date().toISOString(),
      settings: C.settings,
      runtime_bytes: { HonorLog: C.HonorLog.runtime, World: C.World.runtime },
      frames: frames.length,
      total_execution_gas: totalGas,
      chain: "local EVM (@ethereumjs/vm, Shanghai, chainId 1) — deliberately not a network",
      final: { ALICE: snap(pa), BOB: snap(pb), alice_conduct_score: score },
    },
    board: 16,
    players: [{ addr: aKey, name: "ALICE" }, { addr: bKey, name: "BOB" }],
    frames,
  };
  fs.writeFileSync(OUT, JSON.stringify(doc, null, 1) + "\n");
  console.log(`\nwrote ${OUT}: ${frames.length} frames · ${fs.statSync(OUT).size} B · ${totalGas} gas total`);
  console.log("facts, in order:", frames.filter(f => f.fact).map(f => f.fact.kindName).join(" → "));
  console.log("final:", JSON.stringify(doc.meta.final));
}
main().catch((e) => { console.error("record failed:", e.message, e.stack); process.exit(1); });
