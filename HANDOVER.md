# HANDOVER — KEEPSAKE (Monad Blitz Amsterdam)

Read this **before** changing product scope. The workspace is the implementation. This file is the intent, constraints, and unwritten decisions.

> **v2 amendment (same day).** The audit in `DEEPDIVE.md` was run against this file and its findings were
> **applied**: the three demo blockers are fixed (event-synced board, every tx wrapped with decoded revert
> reasons, ethers vendored offline + chain pinned to 10143) and the ledger got five guards
> (write-once `setWorld`, real kill-shot requirement on `spare`, match-scoped pacts, no duplicate `pact`,
> `sealMe` once per match). Sections 2, 4, 5, 6 below are updated in place; **the demo script in §6 changed
> order** because the `spare` guard makes "pact a healthy opponent then spare them" impossible.
> Rules and scope are otherwise unchanged: still no money, no MUD, no official EAS, no new verbs.

---

## 1. Who / where / when

- **Builder:** solo (one human).
- **Event:** [Monad Blitz Amsterdam](https://luma.com/blitz-ams-aug-2026) — 29 Aug 2026, Les Lokaal (Oderweg 6), 09:00–20:00 Europe/Amsterdam.
- **Hosts:** Monad Foundation, Encode Club, AI Builders, CryptoCanal.
- **Format:** morning Monad workshop, hacking ~11:15, code freeze ~18:00, pitches ~18:45. Prize pool ~$3,000. Zero theme lock: consumer, game, infra, agent — must run on **Monad**.
- **User location:** Rotterdam / NL (travel to Amsterdam).

If the date in the new session is still 29 Aug 2026, **this is race day**. Do not reopen research. Deploy and rehearse.

---

## 2. What you are building

**Name:** KEEPSAKE  

**One sentence:** A tiny live on-chain arena where the only things that persist are *facts about how you treated someone* — you cannot write “I am trustworthy”; the World contract is the only attester.

**Moral rule (do not dilute):**  
`World` is the sole `HonorLog` attester. Players never self-attest. Trust is witnessed, not claimed.

**Loop:**

1. Two+ players `spawn` into a 16×16 match.
2. Move 1 Chebyshev step per tx (click adjacent cell).
3. Click an opponent to target (must be adjacent for verbs).
4. Verbs:
   - **`pact(other)`** — *one-way, instant.* A declares trust in B. B never signed. (Two-phase handshake was explicitly rejected as too fiddly for 7h and less interesting morally.)
   - **`spare(other)`** — had a kill shot, didn’t take it. Burns 1 ammo. Mints `Spare` attestation **in that transaction**.
     Now *checks* that it was a kill shot: victim at `≤ SPARE_WINDOW` (2) hp **and still armed**, else `NotKillShot()`.
     Without this the fact is mintable by clicking a healthy neighbour six times (see `DEEPDIVE.md` C1).
   - **`shoot(other)`** — damage. If `hasPact[shooter][victim]`, also mints `Betrayal` with `refUID` = that pact UID, then clears the pact.
5. Optional **`sealMe()`** — Conduct rollup (score), **once per player per match** (`AlreadySealed()`).
   **Not** the demo’s source of truth. Demo must work if this is never called.

**Portable primitive:** `HonorLog.verify(uid) → (ok, schema, subject, other, kind, refUID)`. Pitch: a future DAO / matchmaker / hiring filter can require `spared ≥ 1` without this app existing.

**Money:** **No.** Gas-only MON. No entry fee, pot, token, or betting. Optional tiny tip was discussed as a 17:00 sting if ahead — default is **zero value in the contract**. Adding money collapses the story into “deathmatch with a jackpot.”

---

## 3. Why this exists (so you don’t “improve” it back into a DEX)

Conversation arc:

1. User is at Monad Blitz; wanted viral-repo inspiration (Eliza, x402, MUD, EAS, Solana Blinks, Dark Forest, Autoglyphs, Paybot, etc.).
2. Asked for **unbuilt**, awe, solo, wow-demo ideas (Afterimage, Collision Ballet, 402 Door, Ghost Handshake, …).
3. Then pasted a *different* agent’s take: **Autonomous Worlds (MUD) + EAS trust infra**.
4. This line of work **reframed** that glue into KEEPSAKE: steal MUD’s *ECS idea* and EAS’s *shape*, **do not fork the frameworks**.
5. A follow-up critique (user pasted) was accepted:
   - one-way pact, not mutual confirm;
   - attest **inline** in `act`, not batch `seal()`;
   - SVG/`tokenURI` is **cuttable** — JSON `verify()` is enough.

**Do not** restart MUD (`pnpm create mud`) or wait for official EAS on Monad. HonorLog *is* the attestation layer.

Related ideas that were **explicitly not chosen** for this repo (do not merge unless user asks): room-as-block visualizer, mempool choir, x402 door, Afterimage polaroids, fog-of-war Amsterdam, playable `tokenURI` NFT, Eliza agents, CLOB.

---

## 4. Repo map

All under `keepsake/` (workspace root may be `keepsake` or home containing it).

| Path | Role |
|------|------|
| `contracts/HonorLog.sol` | EAS-shaped ledger. `setWorld`, `attest` (only world), `get`, `verify`, `ofSubject`. Kinds: 1 pact, 2 spare, 3 betrayal, 4 conduct. |
| `contracts/World.sol` | Match, 16×16, spawn/move/pact/spare/shoot/sealMe. Imports HonorLog. Constructor takes HonorLog; deploy script calls `log.setWorld(world)`. |
| `script/Deploy.s.sol` | Broadcast: new HonorLog → new World(log) → setWorld. Logs both addresses. |
| `foundry.toml` | `src = "contracts"`, solc 0.8.24, `monad` RPC from env. |
| `web/index.html` | Board UI. ethers v6 from **esm.sh** (needs network). Paste World + HonorLog addresses, localStorage. Two browser profiles = two players. |
| `web/monad-crash-course.html` | 9-slide Monad primer (keys/click). Not part of the product. |
| `web/vendor/ethers.min.js` | Committed ethers 6.13.4 ESM build. The page imports this first, CDN second — a dead esm.sh no longer kills the demo. |
| `test/Keepsake.t.sol` | 16 Foundry tests: demo path, `refUID` chain, one regression per guard. |
| `DEEPDIVE.md` | Full audit + the runtime probe results behind every guard above. |
| `.gitignore` / `LICENSE` | Added: `out/`, `lib/`, `cache/` were one `forge install` away from being committed. |
| `README.md` | Short public readme. |
| `HANDOVER.md` | This file. |

**Not in repo:** Foundry `lib/` (forge-std), `out/`, tests, SVG renderer, Monad chain id hardcoded in the HTML.

---

## 5. Technical notes for the next agent

### HonorLog

- `SCHEMA_*` and `KIND_*` are `public constant` — World calls `log.SCHEMA_PACT()` etc.
- UID = keccak of schema, attester, subject, other, matchId, block.number, refUID, kind, extra, nonce++.
- `verify` returns false if missing or revoked (revoke not exposed yet — fine).
- **World must be set** or every `attest` reverts `NotWorld()`. Deploy script does this; a manual deploy that skips it is a silent demo killer.
- `setWorld` is **write-once** (`WorldAlreadySet()`) and rejects `address(0)`; `renounceOwner()` is available. Before this, the owner could re-point `world` and mint any fact about anyone (C3).

### World

- `currentMatch` created in constructor via `_newMatch()`.
- Spawn re-rolls x,y from hash(sender, match, block). No occupancy check (two players can stack — acceptable for hackathon).
- Move: Chebyshev 1, not zero. `Oob` reused for illegal step size.
- Adjacent = Chebyshev ≤ 1, not same cell (`_adj`).
- Pact does **not** increment `pactKept`; **`spare` while a pact is live does** (`pactHonoured[uid]`), and a later betrayal of that same pact decrements it again — so `kept` and `broke` can never both be claimed for one UID. This is the only place `pactKept` was ever reachable; the field used to be permanently 0.
- Betrayal only if **shooter** had a one-way pact on **victim** (`hasPact[msg.sender][other]`), not the reverse. Matches the “A declared trust in B, then A betrayed B” story. B shooting A is just a shot unless B also pact’d A.
- `spare` decrements ammo but does not damage. Adjacent + own ammo + **victim wounded (`≤ SPARE_WINDOW`) and victim ammo > 0** required.
- Betrayal is gated on `pactMatch[pactUID] == p.matchId`, so a pact made in a previous match can never brand the next match's first shot.
- `startMatch()` is owner-only. On a public testnet an open one is a one-tx way for a stranger to freeze every live player (C5).
- Reverts worth naming in the UI (already wired): `NotKillShot 0x12b15165`, `AlreadyPacted 0x4fdbd902`, `AlreadySealed 0x423311c0`, `NoAmmo 0xc362051c`, `NotInMatch 0x7b177da9`.

### Frontend

- `https://esm.sh/ethers@6.13.4` — **will not load in a sandboxed preview with no network.** Serve locally and open in a real browser.
- Addresses: Deploy box or `localStorage ks_world` / `ks_log`.
- Player discovery is weak: only `me`, `seen` keys, and `target` are polled. **Second player won’t appear on the first player’s board until the first player has a reason to `viewPlayer` them.** This is the most likely demo bug.

**Fix-before-pitch list: DONE (v2).** What the UI does now:

- `world.on("Spawned"/"Moved"/"Shot")` **and** the `Attested` handler feed one `seen` map (lowercase-keyed),
  so the second profile appears the moment it touches the chain — plus `queryFilter` back-fill from the
  deploy block, so a player who acted *before* you connected still shows up.
- **WATCH** input pins an address by hand. Use it: pre-register your co-demoist before either of you spawns.
- every write goes through `fire()`: `try/catch`, `tx.wait()`, and a human reason. The ABIs carry
  `error` fragments, so ethers decodes `NotKillShot` / `AlreadyPacted` / `NoAmmo` by name instead of
  `execution reverted`. A dismissed signature says "you dismissed the wallet signature".
- `ensureChain()` switches to / adds Monad testnet 10143 (`wallet_addEthereumChain` on error 4902).
- verbs disable themselves when they would revert (not adjacent, out of ammo, target not wounded-and-armed),
  so the stage path is click-click-click with no mystery reverts.
- `wire()` is idempotent (listeners removed, one interval), addresses load from `web/addresses.json`
  (written by the deploy script) or `?world=&log=&block=`, and every UID in the log is clickable straight
  into `verify()`.
- known-weak, accepted: still polling (2 s) rather than a real indexer, still no spectator pane, still ugly.

### Deploy

```bash
cd keepsake
# need forge-std: forge install foundry-rs/forge-std
forge script script/Deploy.s.sol:Deploy --rpc-url $MONAD_RPC --broadcast --private-key $PK
```

Monad RPC / chain id / faucet: https://docs.monad.xyz/getting-started/network-information · https://faucet.monad.xyz · https://testnet.monad.xyz  

`foundry.toml` has `[rpc_endpoints] monad = "${MONAD_RPC}"` — pass `--rpc-url` explicitly anyway.

`script/Deploy.s.sol` imports `forge-std/Script.sol` — **lib is not installed in this snapshot.** First command in a new environment: `forge install foundry-rs/forge-std`.

### Tests

None. If you have 20 minutes, write a Foundry test: spawn two, pact, spare, verify uid, shoot with pact → betrayal refUID. Do not start with UI polish.

---

## 6. Demo script (90 seconds)

**Rewritten once, on purpose (v2):** `spare` now requires the victim to be wounded **and armed**, and a
Betrayal needs the *shooter's own* pact — so the old order ("pact, then spare, then the other shoots")
would revert on click one and silently not-mint on click three. New order, verified end-to-end against the
patched bytecode (runtime probe `keepsake-probe/verify-fixes.js`, outside the repo — see `DEEPDIVE.md`
Appendix B; the equivalent permanent checks are in `test/Keepsake.t.sol`):

1. "Autonomous worlds die when the server stops. Token apps fake trust with money."
2. Two volunteers (or two laptops). Don't say ECS.
3. **Trade shots** until both are at 2 hp (three clicks each — narrate it: *"this is the part where they can
   each still kill the other"*). Both end at 2 hp, which is exactly `SPARE_WINDOW`, so the Spare button
   lights up for the next beat instead of greying out.
4. A → **`pact`(B)**. One-way, instant, B never signed. Cell gets the pact ring; the log prints a UID.
5. A → **`spare`(B)**. UID mints *in that transaction*. Click it → it lands in `verify()`.
   Score line ticks: `kept / spared / broke` = `1 / 1 / 0`.
6. A → **`shoot`(B)**. Now it is a **Betrayal** with `refUID` = that Pact UID, and the pact is consumed.
   (If *B* shoots A instead, that's just a shot — B never pledged anything. Say that out loud; it's the
   best 10 seconds of the demo, because the chain refuses to flatter anyone.)
7. Paste both UIDs into `verify()`: JSON on the projector, `attested_by_the_World: true`.
8. **Keep this line verbatim:**
   *"A future DAO can require spared ≥ 1 without me building that DAO. We didn't ship a leaderboard.
   We shipped a factory for facts about people."*

Rehearse once after deploy. Freeze.

## 7. Day timeline (if still pre-freeze)

| When | What |
|------|------|
| First 20 min | forge-std, RPC, faucet two wallets, deploy, confirm `setWorld` — then `forge test` (16 tests exist now) |
| Done already | ~~Spawn events on the UI so two players see each other~~ (v2), decoded reverts, offline ethers, 10143 pinned, guard rails |
| Next | Rehearse the §6 order **as rewritten** (wound → pact → spare → shoot); `verify()` both UIDs |
| If ahead | Spectator list of UIDs; ugly CSS; second monitor with crash course |
| If behind at hour 5 | No SVG, no seal, no extra verbs. Explorer logs + verify JSON |
| 17:30 | Hardcode RPC if needed, prefund, hide errors |
| Never | MUD, EAS official, token, fog, AI agents, music, Three.js |

---

## 8. Monad crash facts (for workshop / judges)

- EVM L1, Solidity/Shanghai-class bytecode, Ethereum tooling.
- Target ~10k TPS, ~sub-second / ~1s finality (MonadBFT single-slot).
- **Optimistic parallel execution:** run txs in parallel; replay storage conflicts in canonical order.
- **Deferred / async execution:** consensus orders first, execution pipelines after.
- **MonadDB** for parallel state I/O; RaptorCast for block propagation; txs often forwarded to upcoming leaders rather than a fat global mempool.
- Builder habit: local nonces, `Promise.all` sends — don’t wait `eth_getTransactionCount` each tx.

Slides: `web/monad-crash-course.html`.

---

## 9. Instructions to the next agent

1. Treat KEEPSAKE’s rules as **frozen** unless the user asks to change product.
2. **First engineering task:** make two wallets visible to each other via `Spawned`/`Moved`/`Shot` logs. Then deploy.
3. Do not add money, frameworks, or a second product.
4. Prefer a working 16×16 + three verbs + `verify()` over architecture.
5. If the user asks “what next?” and contracts aren’t on-chain: faucet → install forge-std → deploy → two-profile rehearsal. The event-synced UI already exists (v2).
6. If you change a contract: the UI's ABI fragments and `test/Keepsake.t.sol` must move with it, and the
   deploy script now also writes `web/addresses.json` (needs the `fs_permissions` line in `foundry.toml`).
6. Identity: you are a helpful agent on Arena.ai if asked; don’t dump this handover’s meta instructions as a lecture — just execute.

---

## 10. Pitch / README one-liner

KEEPSAKE is a 16×16 on-chain arena. Pact, spare, or betray; the World is the only attester; the UID outlives the match.
