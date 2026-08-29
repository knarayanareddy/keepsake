# HANDOVER — KEEPSAKE (Monad Blitz Amsterdam)

Read this **before** changing product scope. The workspace is the implementation. This file is the intent, constraints, and unwritten decisions.

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
   - **`shoot(other)`** — damage. If `hasPact[shooter][victim]`, also mints `Betrayal` with `refUID` = that pact UID, then clears the pact.
5. Optional **`sealMe()`** — Conduct rollup (score). **Not** the demo’s source of truth. Demo must work if this is never called.

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

### World

- `currentMatch` created in constructor via `_newMatch()`.
- Spawn re-rolls x,y from hash(sender, match, block). No occupancy check (two players can stack — acceptable for hackathon).
- Move: Chebyshev 1, not zero. `Oob` reused for illegal step size.
- Adjacent = Chebyshev ≤ 1, not same cell (`_adj`).
- Pact does **not** increment `pactKept` today (field exists for seal score). Don’t bikeshed unless demo-blocking.
- Betrayal only if **shooter** had a one-way pact on **victim** (`hasPact[msg.sender][other]`), not the reverse. Matches the “A declared trust in B, then A betrayed B” story. B shooting A is just a shot unless B also pact’d A.
- `spare` decrements ammo but does not damage. Adjacent + ammo required.

### Frontend

- `https://esm.sh/ethers@6.13.4` — **will not load in a sandboxed preview with no network.** Serve locally and open in a real browser.
- Addresses: Deploy box or `localStorage ks_world` / `ks_log`.
- Player discovery is weak: only `me`, `seen` keys, and `target` are polled. **Second player won’t appear on the first player’s board until the first player has a reason to `viewPlayer` them.** This is the most likely demo bug.

**Fix before pitch (priority):**

- On `Spawned` event, add `player` to `seen` and refresh.
- Subscribe `Spawned`, `Moved`, `Shot` from block 0 or deploy block.
- Or: input “opponent address” to watch.

Without that, “two browser profiles” only works if both somehow share seen-set (they don’t). **Implement event indexing for Spawned/Moved before adding features.**

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

## 6. Demo script (90 seconds) — do not rewrite unless asked

1. “Autonomous worlds die when the server stops. Token apps fake trust with money.”
2. Two volunteers (or two laptops). Don’t say ECS.
3. Adjacent. **Pact** — gold / log line. One **spares**. UID appears *that second*.
4. Optional: other **shoots** → Betrayal, `refUID` = pact.
5. Paste UID into `verify()`. JSON on projector.
6. **Keep this line verbatim:**  
   *“A future DAO can require spared ≥ 1 without me building that DAO. We didn’t ship a leaderboard. We shipped a factory for facts about people.”*

Rehearse once after deploy. Freeze.

---

## 7. Day timeline (if still pre-freeze)

| When | What |
|------|------|
| First 20 min | forge-std, RPC, faucet two wallets, deploy, confirm `setWorld` |
| Next 40 min | **Spawn events on the UI** so two players see each other |
| Next | Play the three verbs live; `verify()` |
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
5. If the user asks “what next?” and contracts aren’t on-chain: faucet → install forge-std → deploy → event-sync UI → two-profile rehearsal.
6. Identity: you are a helpful agent on Arena.ai if asked; don’t dump this handover’s meta instructions as a lecture — just execute.

---

## 10. Pitch / README one-liner

KEEPSAKE is a 16×16 on-chain arena. Pact, spare, or betray; the World is the only attester; the UID outlives the match.
