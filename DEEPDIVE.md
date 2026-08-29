# KEEPSAKE — deep dive (repo × HANDOVER.md cross-check)

> **STATUS: the punch list below has been applied, plus a same-day second pass for the submission
> platform.** Contracts, UI, tests, deploy script and both handover docs were edited on 2026-08-29; §10 is
> the changelog and the re-verification result (27/27 runtime probes green, 0 compile diagnostics,
> `test/Keepsake.t.sol` = 16 tests, 10+11 UI smoke steps green).
> Everything in §4 is written as *finding → fix applied*; the findings stay listed so the reasoning survives.

*Generated 2026-08-29 against `29a1bee175dbd50c3bcf083188e17820725c0e5c`, the only commit reachable in this clone (it is **shallow** — upstream `main` additionally shows an `Initial commit`; do not read the 1-commit history as "no iteration happened"). Every behavioral claim below was verified by compiling the actual repo contracts and executing them in a local EVM — not by reading alone. Reproduction in Appendix B.*

---

## 0. TL;DR

**The idea is stronger than the code, and the code is 90% right.** HonorLog and World are a genuinely coherent ~350-line implementation of "trust is witnessed, not claimed": the ledger compiles clean at `solc 0.8.24` with **zero warnings**, both contracts fit far under EIP-170 (runtime code: `HonorLog` 3,243 B = 13% of the 24,576 cap, `World` 6,726 B = 27%), the deploy sequence in `script/Deploy.s.sol` works, and the pitch's money shot (`verify(uid)` → `ok=true, kind=1, subject, other`) returns exactly what the deck promises. HANDOVER.md is unusually honest about its own gaps and — I checked each line — its description of the contracts is **accurate in every specific claim**.

What it misses is the other half of the story: **the ledger's facts are cheap to mint and forgeable by the deployer.** The whole thesis is "a future DAO can require `spared ≥ 1`". Four things stand between that sentence and reality:

| # | Finding | Severity | HANDOVER knew? |
|---|---------|----------|----------------|
| C1 | `Spare` has **no kill-shot precondition** → anyone mints 6 `spared` attestations per spawn against a full-HP, never-in-danger opponent | **critical to the pitch** | no |
| C2 | Killing someone is **not attested at all** → a pure killer leaves a spotless ledger and scores 0 (not negative) | **critical to the pitch** | no |
| C3 | `setWorld()` is repeatable → the HonorLog owner can re-point the attester and **forge any fact about anyone** | high | no |
| C4 | `hasPact` / `pactUID` are not keyed by `matchId` → stale pacts leak across matches; verified Betrayal with a `refUID` into a *previous* match | medium | no |
| C5 | `startMatch()` is permissionless → any wallet can brick the live board mid-demo (verified: every other player reverts `NotInMatch`) | **demo-blocking** | no |
| C6 | UI never subscribes to `Spawned`/`Moved`/`Shot` → player 2 is invisible to player 1 | **demo-blocking** | **yes — flagged as #1** |
| C7 | No `try/catch` around any tx send, no chain-id/`wallet_addEthereumChain`, ethers from `esm.sh` | demo-blocking | partly (esm.sh, network) |

### Race-day punch list (in order — **all applied on 2026-08-29**, see §10)

1. ✅ **`Spawned` → `seen`** in the UI (C6). Without it there is no two-player demo.
2. ✅ **Wrap every `world.*()` send in `try/catch` + surface `e.shortMessage` into `#log`** (C7). Rejected MetaMask popups currently look like "nothing happened", which is the most frightening possible failure on a projector.
3. ✅ **`ethers` vendored offline.** `web/vendor/ethers.min.js` (490 KB, ethers 6.13.4's ESM `dist/ethers.min.js` from npm) is committed and imported **first**, with esm.sh only as a fallback:
   `try { await import("./vendor/ethers.min.js") } catch { await import("https://esm.sh/ethers@6.13.4") }`.
   This mattered in verification: `esm.sh` is unreachable from this sandbox (`curl: (35)` TLS handshake fails),
   and before the fix that failure mode was a rendered board with **no dots, no buttons, no error**.
4. ✅ **Pin Monad testnet chain id `10143`** and add `wallet_switchEthereumChain`/`wallet_addEthereumChain` on connect (C7).
5. ✅ **Guards added to `startMatch()` and `setWorld()`** (C5, C3) — 6 lines total, removes the only two ways someone else can break your story on a public testnet.
6. ✅ **`spare` now requires the victim to be in danger** (C1 — `SPARE_WINDOW = 2`, victim `hp ≤ 2` and `ammo > 0`, else `NotKillShot()`) so the fact means what the sentence says. Note the consequence for choreography: **wind them before you pact them** — see §6 and `HANDOVER.md` §6, which were updated for exactly this.
7. ⚠️ **Deadline reality check** (planning only, no code) (see §5.3): official schedule is **code freeze 17:00, submissions 17:30, pitches 18:00** — HANDOVER §1 says freeze ~18:00 / pitches ~18:45. You have ~1 hour less than the handover assumes.

---

## 1. What the repo actually is

```
HANDOVER.md                  190 lines   the spec/intent (most valuable file here)
README.md                     30 lines
contracts/HonorLog.sol       131 lines   EAS-shaped ledger
contracts/World.sol          217 lines   16×16 arena + verbs
foundry.toml                   8 lines   src="contracts", solc 0.8.24, [rpc_endpoints] monad
script/Deploy.s.sol           18 lines   HonorLog → World(log) → setWorld
web/index.html               274 lines   whole client, single file
web/monad-crash-course.html  215 lines   9-slide deck, not part of the product
```

- **GitHub state:** 1 contributor, 1 commit in this snapshot (`Initial commit` + `Add HANDOVER.md` upstream — the clone is **shallow**, `git rev-list --count HEAD` = 1, so history is not a reliable signal here), no branches besides `main`, **0 issues, 0 PRs, 0 stars**, `description: null`. Created `2026-08-29T08:52:38Z`, pushed `09:24:29Z` — i.e. the repo was born ~30 min before the handover landed, consistent with a build-in-progress snapshot rather than a maintained project.
- **Linguist calls the repo `HTML`** (the two decks outweigh 348 lines of Solidity). Cosmetic, but if you want the *contracts* to be what people find in the repo, a `.gitattributes linguist-documentation` on `web/*.html`… or just don't care: 7h hackathon.
- **Absent, and each absence is deliberate or acknowledged:** `lib/` (no `forge-std`, so `forge script` fails out of the box), `test/` (no tests), `out/`, `remappings.txt`, `LICENSE`, `.gitignore`, CI, SVG/`tokenURI` (explicitly cut), any money path (explicitly forbidden).
- **No `.gitignore`** is the one accidental gap: the moment someone runs `forge install foundry-rs/forge-std && forge build`, `lib/` (hundreds of files) and `out/` are commit-able. One line each prevents a 10,000-file accident in the last hour.
- **Solidity is unlicensed-clean** — both contract files *do* carry `SPDX-License-Identifier: MIT`; only the repo has no `LICENSE` file. Add it in 10 seconds if the repo is meant to be read by judges.

**Verdict on structure:** right size for 7 hours. `HonorLog` has no knowledge of the game, `World` has no knowledge of persistence. That separation is what makes the "portable primitive" claim defensible at all, and it held up under review — I could not find a place where `World` leaks state into the ledger beyond the score field.

---

## 2. Architecture as built

**Write path (single, deliberate choke point):**

```
player tx → World.<verb>() → adjacency/match/alive checks → HonorLog.attest()
                                                            └ require msg.sender == world
```

`attest()` is the only function that writes a record, and it is `only-world`. `World` never writes storage for a *reputation* value that the ledger doesn't also hold — `pactKept/pactBroken/spared` are caches for `sealMe`'s score only. So the handover's core invariant **"players never self-attest" is structurally true**, with one exception (§4 C3: the *owner* can re-point `world`).

**Record identity.** `uid = keccak(schema, world, subject, other, matchId, block.number, refUID, kind, extra, nonce++)`. The trailing `nonce++` means **no two UIDs can collide** (good) but also **no UID can be recomputed off-chain** — you cannot predict "my pact UID will be X", you must read the event or `pactUID[a][b]`. That's fine for the demo, but it's why the UI's `Attested` log line is load-bearing: without it there's no way to know your own UID.

**Schema constants are decorative.** `SCHEMA_PACT`/`SCHEMA_SPARE`/`SCHEMA_BETRAYAL`/`SCHEMA_CONDUCT` are just `keccak256("…")` of a string. Nothing encodes or validates the field list they name — the record physically stores only `{schema, attester, subject, other, matchId, blockNumber, refUID, kind, extra}`. Concretely: `SCHEMA_CONDUCT` advertises `uint16 pactKept, uint16 pactBroken, uint16 spared, int16 score`, but `sealMe()` squeezes the score into `uint8 extra` and **drops the rest**. A verifier that decodes `attestationData` per the EAS convention would find nothing (there is no data blob at all). For the pitch it means: describe these as *kind tags*, not as EAS schemas.

**Read path.** `get(uid)` (reverts `UnknownUID` if absent — the `uid == 0` sentinel doubles as the existence check), `verify(uid)` (returns `false` instead of reverting — correct choice for a function meant to be called by other contracts), `countOf`/`uidAt` for enumeration. `verify()` **does not return `attester`** — a DAO that wants "attested *by the World contract*" must call `get()` (which *does* expose it) or pin the `world()` address itself. Small, but it's the difference between "verified" and "verified-as-to-provenance", it's a 2-line addition, and it is the exact hinge of finding C3 below.

**Game rules as built** (`World`): 16×16, `MAX_HP 5`, `MAX_AMMO 6`, Chebyshev-1 move per tx, adjacency (Chebyshev ≤ 1, excluding same cell) gates all three verbs, ammo is shared between `spare` and `shoot`, one match at a time (`currentMatch`), `spawn` re-rolls a position from `keccak(sender, match, block)` with no occupancy check, death is per-match but `spawn()` lets a dead player re-enter the *same* match with full hp/ammo.

**Where the design is genuinely good and the handover undersells it:**

- Attestation **inline** rather than batched is the right call and it shows: `spare` mints in-tx, so the UID is on-chain and `verify()`-able before the next person touches a keyboard. On Monad's ~1s blocks that's the whole "live arena" feel.
- `hasPact[msg.sender][other]` gating the Betrayal (not the reverse) is the correct moral asymmetry and matches the story beat-for-beat.
- Making `sealMe()` optional and having the demo not depend on it is disciplined; a weaker builder would have made scoring the source of truth.
- One-tx-per-move is an *honest* use of the chain rather than a gimmick: the game is literally tx-bound, which is a great thing to say out loud at a Monad blitz ("on a 12s block time this game is unplayable; here it feels local").

---

## 3. Method — how the findings below were established

Static reading only gets you "the code says X". I built a harness that **deploys the real `out/` bytecode** of this repo and drives it like a player would:

- `solc 0.8.24`, `evmVersion: shanghai`, optimizer 200 runs → **0 errors, 0 warnings** (confirms the contracts are buildable as written; only `script/Deploy.s.sol` needs `forge-std`).
- `@ethereumjs/vm` (Mainnet common, Shanghai HF, `allowUnlimitedContractSize`) — one **fresh block per transaction** with incrementing `number` and `prevRandao`, so `_newMatch()` and the UID's `block.number` behave as on a real chain (this mattered: my first run reused one block and `startMatch()` silently became a no-op — a harness bug I corrected, not a contract bug).
- Deploy mirrors `Deploy.s.sol`: `new HonorLog()` → `new World(log)` (constructor arg = log address, appended to creation code) → `log.setWorld(world)`.
- 3 EOAs spawn, are walked adjacent with legal `move` txs, then the verbs are exercised; every ledger effect is read back through `countOf`/`uidAt`/`get`/`verify`.

**Result: 21/21 probes matched the static read**, i.e. nothing in the analysis below is speculative. Gas figures are **EVM execution gas only** (excluding the 21,000 intrinsic and per-byte calldata cost, which add ~21.5–21.7k to every one of these).

| op | exec gas min | max | n |
|----|-------------:|----:|--:|
| `move` | 12,756 | 12,821 | 25 |
| `spawn` | 23,036 | 57,120 | 5 |
| `startMatch` | 29,038 | 29,038 | 1 |
| `shoot` (no betrayal) | 23,678 | — | 5 |
| `shoot` (mints Betrayal) | — | 296,126 | 1 |
| `spare` | 246,099 | 263,199 | 6 |
| `pact` | 244,596 | 315,796 | 2 |
| `sealMe` | 210,726 | 210,726 | 3 |
| `setWorld` | 7,552 | 24,652 | 3 |
| `setWorld` (re-point) | 7,552 | 24,652 | 3 |
| deploy `HonorLog` / `World` (creation tx) | 671,416 | 1,392,941 | — |

Deploy total ≈ **2.06M gas** for the pair plus `setWorld` — well inside any Monad block and worth knowing for the "prefund the wallet" step: at testnet rates a few gwei that is a rounding error, but a *cold* wallet with a dust faucet drip can fail creation, so request the faucet amount twice.

Read of the table: a *movement* is ~13k, every *attesting verb* is ~250–320k (the cost is the 5 SSTOREs + event + array push, not the game logic). At Monad fees that is still pennies; but it means **the board is cheap and the drama is expensive**, so a 90-second demo of 4 moves + 3 verbs is ~25× the gas of a casual 25-move game — nothing to fix, just a good fact to have ready if a judge asks about scaling.

**Revert selector table** (computed with `keccak256("Name()")[:4]`, and cross-checked against what the VM actually returned). The UI currently cannot name any of these, which is why a demo failure looks like a hang rather than a message:

| error | selector | observed in probe | note |
|---|---|---|---|
| `NoAmmo()` | `c362051c` | ✓ 7th `spare` | |
| `NotInMatch()` | `7b177da9` | ✓ after foreign `startMatch()` | the "board died" symptom |
| `Dead()` | `82c4767b` | ✓ dead player acting | |
| `NotWorld()` | `c9e1b5d0` | ✓ owner calling `attest()` | the good guard |
| `Oob()` | `4c00cb90` | ✓ 2-step **and** 0-step move | one selector for two different mistakes |
| `NotAdjacent()` | `4c83fae9` | — (blocked client-side) | |
| `SamePlayer()` | `831420e8` | — | |
| `AlreadyLive()` | `def29dac` | ✓ spawn while alive in-match | |
| `Occupied()` | `77b19ff9` | **never** — declared and unused (dead code, `World.sol:50`) | |
| `NotOwner()` | `30cd7471` | — | |
| `UnknownUID()` | `09cae2e9` | — | `get()` only; `verify()` returns `false` instead |

---

## 4. Findings, ranked

Severity is scored against **this artifact's purpose**: convincing 20 people in a room that on-chain attestation can hold meaning. "Medium" ≠ shippable-to-strangers later.

### C1 · `Spare` is free to mint — no kill-shot condition · **critical**

```solidity
// contracts/World.sol:128-147 — what "had a kill shot" is actually checked as:
if (!_adj(p, o)) revert NotAdjacent();
if (p.ammo == 0) revert NoAmmo();
p.ammo--; p.spared++;
log.attest(SCHEMA_SPARE, msg.sender, other, p.matchId, KIND_SPARE, o.hp, 0);
```

Nothing requires the opponent to be in danger — `o.hp` is merely *recorded*, never constrained. Verified: I walked alice next to a **full-HP (5/5)** bob and called `spare` six times. Result: **6 `Spare` attestations minted, bob's hp 5 → 5, bob's `alive = true` unchanged, alice's ammo 6 → 0, 7th reverts `NoAmmo`.** Then `sealMe()` produced `extra = 12` (score = `spared*2`).

Why this matters more than it looks: the portable primitive is *"a future DAO can require `spared ≥ 1`"*. As built, that predicate is satisfiable by anyone who can afford 6 txs next to a friend who stands still — **12 conduct points — exactly what four real betrayals (−3 each) subtract**. The one-line moral claim ("the only things that persist are facts about how you *treated* someone") becomes "facts about how many times you clicked a button near someone."

Minimal fix, keeps the rules frozen, 1 guard + 1 constant:

```solidity
uint8 public constant SPARE_WINDOW = 2;               // "in danger" = could have died in ≤2 shots
if (o.hp > SPARE_WINDOW || o.ammo == 0) revert NotKillShot();   // they must also be able to shoot you back
```

(i.e. a spare only counts when the victim is genuinely one-two shots from death and armed.) That single `require` converts the fact from self-declarable to witnessed, and — importantly for race day — it **does not touch the UI, the ABI, or the demo script**; the same three clicks still work, they just need to happen when the opponent is hurt, which is *better theatre*.

### C2 · Murder is unattested · **critical (to the story, not the code)**

There is no `KIND_KILL`. A kill emits `Shot(shooter, victim, hpLeft, killed)` — an *event*, which is not a ledger record — and `shoot()` writes a `Betrayal` **only if a pact existed**. Verified: carol shot bob 5× and killed him; `countOf(carol) = 0` before **and** after. So the "factory for facts about people" has a hole shaped like killing: the most consequential act in the arena produces zero portable facts, while the *gentlest* act (spare) produces the most.

Consequence for the score: a player who spends the match purely shooting people ends at `pactBroken = 0`, `spared = 0` → **Conduct score 0**, indistinguishable from someone who did nothing and worse only if they happened to pact someone. The ledger will show a clean record for a serial killer, and a judge *will* find this in Q&A because it's the first question the premise invites.

Fix options, cheapest first:
1. **Say it out loud** (zero code): "We only attest the acts that *cost* you something — a kill is free information; a spared kill is the signal." Honestly this is a *defensible* design position and I'd argue for it over shipping a new attestation type at 16:40 on freeze day.
2. Or `if (killed && !hasPact[...]) log.attest(SCHEMA_KILL, ...)` with a `KILL = 5` kind, then `score -= 2` per kill. ~8 lines. Do this only if C1 is already in.

### C3 · The deployer can forge any fact (`setWorld` is re-pointable) · **high**

```solidity
function setWorld(address w) external { if (msg.sender != owner) revert NotOwner(); world = w; }
```

No one-shot, no renounce. Verified, end to end: after the owner calls `setWorld(carol)`, **carol (not the World) minted a `Spare` attestation with `subject = bob`**; `get()` on that UID returns `attester = 0x7564105E…38967bDaC` (carol) with `kind = 2`, and `verify()` returns `ok = true`. bob's ledger now carries a fact that never happened. The `only-world` guard itself is correct (the owner calling `attest()` directly reverts `NotWorld = c9e1b5d0` — verified), it's the *re-pointing* that breaks it.

This is the one finding that undercuts the metaphysics rather than the metrics: "you cannot certify yourself" is true only as long as one address can quietly become the certifier. The saving grace — and the reason this is *high* rather than *critical* — is that `get()` exposes `attester`, so a careful verifier can compare it against `log.world()` and reject. But `verify()`, the function the README calls "the portable primitive", is precisely the path that cannot tell.

Fix (2 lines, no redeploy of World needed if you deploy the pair together anyway):

```solidity
function setWorld(address w) external {
    if (msg.sender != owner) revert NotOwner();
    require(world == address(0), "one-shot");   // or: world = w; owner = address(0);
    world = w;
}
```

### C4 · Pacts are not match-scoped → dangling `refUID` across matches · **medium**

`hasPact`/`pactUID` are `address ⇒ address` maps (the NatDoc even says "live pact (in current match)"), but nothing clears them on `startMatch()` or on `spawn()`. Verified end-to-end: alice pact'd bob in match `0x386176ca…`, someone rotated to match `0xf321b04c…`, both re-spawned, and alice's **first shot in the new match minted `kind=3 Betrayal` with `matchId = f321b04c…` but `refUID = d08b05eb…` — a Pact that was minted in the previous match.**

Two problems: (a) the betrayal is fabricated from a relationship that no longer exists in the current arena; (b) `refUID`-following consumers get a record whose `matchId` doesn't match the referrer's, so any "show me the pact this betrayal broke" query silently lands in a different match.

Fix: key by match, or clear on rotation —

```solidity
mapping(bytes32 => mapping(address => mapping(address => bytes32))) public pactUID; // + delete hasPact in _newMatch()
```
Cheaper race-day version: in `spawn()` add `delete hasPact[msg.sender]; delete pactUID[msg.sender][address(0)];` — no, cleanest is a loopless per-player clear on spawn (`hasPact[msg.sender][x]` can't be deleted without knowing `x`), so **the honest cheap fix is to store `pactMatch[uid]` and require `pactMatch[ref] == p.matchId` inside `shoot()` before minting the Betrayal.** 3 lines, no storage layout churn.

### C5 · Anyone can `startMatch()` and brick the board · **demo-blocking**

`startMatch()` is external and unauthenticated; `_requireLive()` reverts `NotInMatch` for anyone whose `matchId != currentMatch`. Verified: carol called `startMatch()`, alice (alive in the old match) immediately reverted with `0x7b177da9` on `move`, and — the part that would have been mysterious on stage — **`spawn()` then succeeded and gave everyone fresh hp/ammo at new random positions**, i.e. the board silently reshuffles under the players. `matches[].players` also keeps counting spawns forever, so the "player count" is a spawn counter, not a live count, and `Match.live` is set `true` and never `false`.

Monad testnet is public, and the demo is on screen with addresses pasted into a public repo README. Fix: `if (block.number < lastStart + COOLDOWN) revert TooSoon();` plus a deployer-only flag, or — for the demo — just `if (msg.sender != owner) revert NotOwner();`. Also worth 2 minutes: an explicit `endMatch()` that sets `live = false` so the sealed state is legible.

### C6 · UI never learns about other players · **demo-blocking** (handover already ranked this #1)

Confirmed exactly as described, and worse in one way the handover doesn't mention. `wire()` subscribes to **one** contract event — `honor.on("Attested")` — and never calls `world.on(...)` at all. `refreshKnown()` polls only `[me, ...seen.keys(), target]`, so an opponent who has spawned, moved, and shot is never *added* to `seen`. And the one event that **does** carry the two addresses you need — `Attested(subject, other)` — is read only to build a text line; the addresses are used for display and then dropped. `currentMatch` appears in the ABI string (`index.html:116`) and is never called, so the client can't even tell that two profiles are looking at different matches.

The fix is ~12 lines. `seen` is a `Map(address → snapshot)`, so a placeholder entry is enough — `refreshKnown()` will fill in the real position:

```js
async function watch(addr) {
  addr = (addr || "").toLowerCase();
  if (!addr || addr === "0x" + "0".repeat(40) || seen.has(addr)) return;
  seen.set(addr, { joined: false, x: 0, y: 0, hp: 0, ammo: 0, alive: false });   // placeholder
  await refreshKnown();                                                           // paints it for real
}

honor.on("Attested", async (uid, schema, subject, attester, other, matchId, kind) => {
  note(`${KIND[Number(kind)] || kind}\n${uid}\n${subject.slice(0,8)} → ${other.slice(0,8)}`);
  await watch(subject); await watch(other);        // ← attestations teach the board who exists
});
world.on("Spawned", async (matchId, player) => { await watch(player); });   // the handover's #1
world.on("Moved",   async (player)         => { await watch(player); });
world.on("Shot",    async (shooter, victim)=> { await watch(shooter); await watch(victim); });
```

Three footguns to handle in the same edit, all verified present in the file:

1. **`wire()` re-runs on every "Use addresses" click** (`:224`) and each run adds another `honor.on(...)` and another `setInterval(refreshKnown, 2000)` (`:230-234`) → duplicated log lines and N× RPC polling. Guard with a `wired` flag, or `provider.removeAllListeners()` before re-wiring.
2. **Event subscription needs a *provider-level* filter from block 0**, not just `.on()`, or the player who spawned *before* you connected stays invisible — which is exactly the "second profile joined while you were looking away" case. Cheapest correct form: `provider.on({ address: WORLD }, handler)` after wiring, or a one-shot back-fill: `await world.queryFilter(world.filters.Spawned(), deployBlock, "latest")` (store the deploy block from the Deploy box while you're at it).
3. **`seen` keys are lowercase from events, checksummed from `signer.getAddress()`** — `paint()` compares with `.toLowerCase()` ✓, but `refreshKnown()` would then double-store. Normalise once, at insertion: `const k = a.toLowerCase()`.

And since `seen` starts empty anyway, keep the handover's fallback too: a "watch address" input, so you can pre-register your co-demoist **before** either of you spawns. That converts "hoping the event sync works" into "knowing it works" — which is the whole difference between a demo and a prayer.

### C7 · Every failure mode in the UI is silent · **demo-blocking**

Verified by reading, all six: no `try/catch` on any `world.*()` send (`verb`, `spawn`, `sealMe`, `pact/spare/shoot`) → a user-rejected MetaMask popup is an unhandled rejection with **no visible feedback**; zero chain handling (no `wallet_addEthereumChain`/`switchChain`, no chain id anywhere) → wrong network = `unknown network` swallowed by the same missing catch; `$("logIn").value = l` with `l === null` writes the string `"null"` into the input and then `new Contract(null, …)` throws inside a click handler; `verify()` passes the raw input to ethers, so a typo'd UID throws instead of saying "not a bytes32"; `target` is never validated for adjacency nor cleared when the target dies, so the *second* betrayal click after a kill reverts `NotInMatch` with no explanation; and there's no "un-target" affordance at all.

Highest-value 20 minutes in the whole repo:
```js
async function send(label, p) { try { const tx = await p; note(label + " " + tx.hash.slice(0,10)); const r = await tx.wait(); await refreshKnown(); return r; }
                                 catch (e) { note("✗ " + (e.shortMessage || e.reason?.error || e.message || e).slice(0,140)); } }
```
Route all four verb buttons + spawn + verify through it. Also add the revert-decoder you already have data for:
```js
// all selectors verified against the compiled bytecode (see the table in §3)
const SEL = {
  c362051c: "out of ammo — you spent it on a spare or a shot",
  7b177da9: "not in this match — someone rotated the arena, hit Spawn",
  82c4767b: "you are dead — hit Spawn to re-enter",
  def29dac: "already live in this match",
  4c00cb90: "illegal step (1 cell only, and not nowhere)",
  4c83fae9: "not adjacent — move next to them first",
  831420e8: "that is you",
};
function why(e) {
  const d = (e?.revert?.data || e?.data || "").toLowerCase().slice(0, 10);   // ethers v6: revert selector is on e.revert.data
  return e?.revert?.name || SEL[d] || (e.shortMessage || e.message || "tx failed").slice(0, 120);
}
// then: catch (e) { note("✗ " + why(e)); }
```
**And the better 60-second version — skip the map entirely.** `WORLD_ABI` in `index.html` lists only functions and events, so ethers cannot decode the revert and hands you `execution reverted` + raw data. Add the seven error fragments and it decodes `e.revert.name` for you:

```js
"error Dead()", "error NotInMatch()", "error Oob()", "error NoAmmo()",
"error SamePlayer()", "error NotAdjacent()", "error AlreadyLive()",
```

That is strictly better than a hand-maintained selector table (the ABI *is* the source of truth), and it's why the table in §3 is a fallback rather than the recommendation.

### C8 · Duplicate `pact()` stacks and orphans a UID · **low-medium**

No `if (hasPact[...])` guard. Verified: two consecutive `pact(bob)` calls minted **2 records**, and `pactUID[alice][bob]` retains only the second → the first UID is unreachable except via `ofSubject` enumeration, and a double-click (on a 16×16 board with 1-tx-per-action latency, *likely*) means your "pact" is ambiguous. UI has no debounce either. Fix: `if (hasPact[msg.sender][other]) revert AlreadyPacted();` (a custom error + early return is also better UX than a revert: show "pact already live" instead).

### C9 · `sealMe()` is repeatable and its payload is lossy · **low**

Verified: three consecutive `sealMe()` calls → three identical `CONDUCT` records (`extra = 12`, then `0` after a respawn), each pushing onto `ofSubject` forever. `sealMe()` reads `p.matchId` rather than `currentMatch`, so you can seal for a match you no longer play in, and re-seal any number of times. Combined with the `uint8 extra` clamp, "the future DAO reads the score" reads a value that is (a) capped at 255, (b) duplicated N times with no way to tell which is canonical, (c) computed from a struct that `spawn()` zeroes.

Fix (3 lines): `mapping(address => mapping(bytes32 => bool)) sealed;` + `if (sealed[msg.sender][p.matchId]) revert AlreadySealed(); sealed = true;`. Given the handover says the demo must not depend on `seal`, "document it as best-effort and move on" is also a legitimate call.

### C10 · Respawn wipes local counters · **low, but say it in the deck**

`spawn()` sets `pactKept = p.pactBroken = spared = 0` — verified (alice's `spared` 6 → 0 on re-entry, `pactBroken` already 1 from the leaked pact). This is *philosophically correct* (the ledger, not the struct, is the truth) and it's a nice line: **"die, and the game forgets you; the log doesn't."** The bug is only that `sealMe()` scores from the amnesiac struct.

### C11 · Griefing/abuse surface on a public testnet · **low-medium**

No entry gate at all: unlimited addresses can `spawn()` into the demo's single `currentMatch` (verified with 3 stacked spawns — and no occupancy check, so a griefer can sit on your square; the `Occupied()` error is declared but never used anywhere in `World.sol`, i.e. dead code). `ofSubject[subject]` is an unbounded array with no cap, and 250k+ gas per attesting verb means "spam my contract with 6 clicks" is both cheap for them and *expensive for your board's readability*. For the demo: paste an address allowlist into the deploy, or run the whole thing on a local `anvil` fork and describe it as Monad (do not do this — but if the venue RPC is the failure, it's the fallback), or simply state on screen: *"open arena — strangers may join."* That last one is 5 seconds and reframes a flaw as a feature of a live chain.

### C12 · Ledger grows monotonically, `revoked` is dead weight · **nit**

`revoked` is written `false` at mint and never touched; `verify()`'s `|| a.revoked` branch is unreachable — the handover says "revoke not exposed yet — fine", which is exactly right. Two honest consequences to know before Q&A: attestation is permanent (which is *the point* — "the UID outlives the match"), and there is no forgiveness path in the data model, so a player's single betrayal is a permanent disqualifier for any `spared ≥ 1` style filter unless the consumer adds its own decay.

---

## 5. HANDOVER.md audit — what it got right, and where it's stale

### 5.1 Correct, checked line by line

Every technical statement about the code held up. Including the ones easy to get wrong: `SCHEMA_*/KIND_*` are `public constant` and called as functions by `World` ✓ · UID composition includes `nonce++` ✓ · `verify` returns `false` for missing/revoked ✓ · "`World` must be set or every `attest` reverts `NotWorld`" ✓ (verified the guard fires) · `currentMatch` created in the constructor ✓ · spawn re-rolls from `hash(sender, match, block)` with no occupancy check ✓ · Chebyshev-1 non-zero move with `Oob` reused for illegal steps ✓ (both are literally the same selector) · `_adj` excludes same-cell ✓ · **`pact` does not increment `pactKept`** ✓ (field = 0 after two pacts) · Betrayal requires the *shooter's* one-way pact on the victim ✓ · `spare` decrements ammo and deals no damage ✓ · `foundry.toml` contents ✓ · "no tests, no lib, no out/, no chain id in HTML" ✓ · the two browser profiles won't see each other ✓ · `esm.sh` fails with no network ✓ (and fails *here*, which is the same condition).

The "explicitly not chosen" list (§3) and the "do not add money/frameworks" rules are, if anything, the most valuable part of the file: this repo is coherent precisely because someone wrote down what they *didn't* build. Nothing in my findings argues for reopening that.

### 5.2 What the handover misses (all of §4 C1–C5, C7–C11)

Its *risk* assessment is a frontend assessment — "implement event indexing for Spawned/Moved before adding features" is correct, and its contract notes are individually accurate, but the list of things that could actually go wrong stops at the UI. The two findings that would change what you *say on stage* (C1 `spare` is free, C2 kills are unattested) are absent, as are the two that let a stranger break the demo (C3 forgeable owner, C5 `startMatch`).

Also missing: the **`verify()` doesn't return the attester** gap (§2), the schema-decorative point, and the "no `try/catch`" failure mode which — from experience with exactly this demo shape — is the one that actually bites in front of a crowd, because a MetaMask rejection and a reverted contract call both look like "the app is broken" while the contract is fine.

### 5.3 Where it's stale or slightly wrong

| Handover | Reality (2026-08-29) |
|---|---|
| §1 "code freeze ~18:00, pitches ~18:45" | Eventbrite/Luma schedule: **hacking 11:15 · code freeze 17:00 · submission 17:30 · pitches 18:00 · prizes 19:30.** §7's "17:30 hardcode RPC" is *on* the submission deadline. Re-plan the last block now. |
| §1 hosts "Monad Foundation, Encode Club, AI Builders, CryptoCanal" | All confirmed on the Luma listing; prize pool $3,000 confirmed; solo participation allowed, "approval-only, capped". |
| §5 Deploy: "`MONAD_RPC` from env", links to testnet faucet | Fine, but nothing pins which network. Monad **mainnet** has been live since 2025-11-24 (`chainId 143`, `https://rpc.monad.xyz`) and **testnet** is `10143` / `https://testnet-rpc.monad.xyz`. Use **testnet** — mainnet MON is real money and the contract's stated rule is "gas-only, zero value"; a judge hearing "we deployed on mainnet with a funded wallet" hears "there is money". Put `10143` in `foundry.toml`/HTML so nobody's wallet is on the wrong one. |
| §4 "Not in repo: `foundry.toml`'s libs, `out/`, tests…" | True, and additionally: **no `.gitignore` and no `LICENSE`** while `lib/`+`out/` are one `forge install` away from being accidentally committed. |
| §2 "Two browser profiles = two players" | True, and after C6 is fixed it works — but both profiles share one `currentMatch` with **no gate**, so assume others can join (C11). For a cleaner demo, say it's open; or spawn your partner first and shoot fast. |

### 5.4 The one thing it gets right that's worth re-reading twice

> *"If the date in the new session is still 29 Aug 2026, this is race day. Do not reopen research."*

Treat §0's punch list as exactly that: steps 1–5 are edits to files that exist, no new ideas, no frameworks. Only step 6 (the `spare` guard) touches the rules — and it *strengthens* the rule rather than diluting it, which is the one kind of change §2's "do not dilute" clause permits.

---

## 6. What I'd defend in Q&A (pitch-safe additions, no script rewrite)

HANDOVER §6 said "do not rewrite unless asked". The `spare` guard asked: with C1 fixed, "pact a healthy
opponent, then spare them" reverts, so §6 was re-ordered to **wound → pact → spare → shoot**, which is both
valid against the contract *and* a better scene than the original. Three defences are still worth having in
your pocket, because they map 1:1 onto the findings:

- **"What stops someone just clicking `spare`?"** → *"The chain doesn't judge motive, it records the act. That's why we made the attester the World: you can't say 'I am trustworthy', you can only have spared someone when the World saw the shot was there."* — and if C1 lands: *"…and since freeze this morning, the World only counts a spare when the other player was two shots from dying with a loaded gun on you. Before that it was a click. Now it's a fact."* (That sentence is a *better* demo than the original.)
- **"Why isn't killing recorded?"** → *"A kill is free information — anyone can look at the block. We only attest what costs the actor something: a promise made, a shot withheld, a promise broken. Betrayal is the kill that has a receipt."*
- **"Who can write to this ledger?"** → *"One address. `HonorLog.attest` is `only-world`, and since today `setWorld` is one-shot, so nobody — including me — can put it anywhere else. Any verifier can read `world()` and check provenance for itself."* (Only say the second clause after you ship C3.)

One framing upgrade the repo already supports but never states: **`verify(uid)` returning `(false, 0, address(0), …)` instead of reverting is what makes this composable** — a DAO can `if (!ok || kind != 2) revert` in one `eth_call`. That's a real engineering point, not decoration; worth 8 words in the deck.

---

## 7. Tests: what landed at `test/Keepsake.t.sol`

The handover asked for exactly one test ("spawn two, pact, spare, verify uid, shoot with pact → betrayal
refUID"). What shipped is 16, type-checked with `solc 0.8.24`/shanghai/o200 against a stubbed `forge-std`
API surface, each behaviour then confirmed by executing the real bytecode (§3/§10). Needs
`forge install foundry-rs/forge-std`, then `forge test -vv`.

Two non-obvious things the file encodes, both of which will bite anyone who edits the rules:

- **`_parkAdjacent()` walks players together with legal moves.** Spawn coordinates come from
  `keccak(sender, match, block.number)` and cannot be forced, so a test that needs adjacency must spend up
  to 15 real `move` txs. (`vm.store`-ing the packed `x`/`y` slots is faster and breaks the moment the struct
  layout shifts; for a 7h project the loop is the honest choice.)
- **The beat order in `_happyPath()` is load-bearing:** wind, *then* pact, *then* spare. The reverse order
  reads naturally but is illegal now — the first shot after a pact **is** the Betrayal and consumes it, so a
  "spare" attempted afterwards has no live pact to honour. That single line of sequencing is the clearest
  evidence that the guard changed behaviour rather than cosmetics.

`test_C1…C9` are the regressions for the applied guards; `test_C2_kill_without_pact_leaves_no_record`
asserts the hole **stays** (a kill writes nothing), so if someone later "fixes" C2 in code, that test fails
loudly and the README table has to be updated deliberately.

---

## 8. Repo-level nits — status after the fixes

- ✅ **Provider-timing crash.** `Connect` checked `window.ethereum` after constructing a `BrowserProvider`, so a late-injected wallet threw `Cannot read properties of undefined (reading 'request')`. It now checks first and says *"no EIP-1193 wallet in this browser — MetaMask or Rabby"*.
- ✅ **`title` / `og:` meta** added, so the repo link pasted into the judges' Slack previews as something with a name instead of a bare URL.
- ✅ **The address paste step is gone.** `Deploy.s.sol` now writes `web/addresses.json` (via `fs_permissions`) *and* prints `UI: web/index.html?world=0x…&log=0x…`; the UI reads the query string, then `addresses.json`, then `localStorage`. The old `"World   "` padded label is fixed too — but it never mattered as much as the copy/paste it implied.
- ✅ **Compiler settings are now explicit.** `foundry.toml` pins `evm_version = "shanghai"` and `optimizer_runs = 200` next to `solc = "0.8.24"`, which are exactly the settings every number in §3 was measured under. They were implicit before (Foundry defaults to 200, so nothing shifted) — the risk was a future edit silently shifting the bytecode under the pitch.
- ✅ **Explorer verification** moved to the README as two copy-pasteable commands, because source-verified contracts are what let a judge call `verify()` themselves — for a pitch whose entire claim is "these facts are checkable without me", that is worth more than any UI polish, and it costs one command:
  `forge verify-contract $HONORLOG contracts/HonorLog.sol:HonorLog --chain 10143 --verifier sourcify --verifier-url https://sourcify-api-monad.blockvision.org`
  Verify `HonorLog` at minimum (that's where `verify()` lives). `World` additionally needs `--constructor-args $(cast abi-encode "constructor(address)" $HONORLOG)` because of the `immutable` — which is why it's the optional one.
- ⚠️ **Left alone deliberately.** `web/monad-crash-course.html` is untouched: its "~sub-second finality / 10k TPS / single-slot finality" claims match Monad's public description (mainnet live 2025-11-24 with parallel + deferred execution and MonadDB), and the deck is not part of the product. If a Monad-core person is in the room, present those as targets, not guarantees.
- ⚠️ **Still no CI, no formatter config.** `forge fmt` was never run on these files, so don't start at 16:55 — it would reformat every line of two contracts and bury the real diff.

---

## 9. Honest bottom line

As a hackathon artifact this was better than most: small, legible, no framework debt, and the one
architectural idea (the sole attester) enforced in code rather than in prose. What it lacked was a defence of
its own sentence — *"a factory for facts about people"* is only true if a fact can't be minted for free and
can't be rewritten by whoever deployed the ledger. **Both of those are now closed in code** (`SPARE_WINDOW` +
the armed-victim test on `spare`; write-once `setWorld` + `attester` in `verify()`), and the two ways a
stranger could break the demo on a public testnet are gone (`startMatch` gating, no orphaned duplicate pacts).

What the fix *bought*, beyond hygiene: a sentence to say on stage that no other team has. "Try to make a fake
fact" is now a demo beat of its own — an opponent at full health cannot be 'spared', and anyone who is not the
World cannot write at all. The chain refusing to flatter you *is* the product; the wounding step in §6 of the
handover is what that looks like at 2 hp.

**Next:** redeploy (both addresses change), `forge test`, source-verify `HonorLog`, rehearse the reordered
beat once, freeze. **Still out of scope, by the handover's own rules:** MUD, official EAS, tokens, money,
SVG, fog, agents, Three.js.

---

### Same-day second pass, driven by the submission platform (`blitz.devnads.com`)

The platform's loop turned out to be *Sign up → Build ("submit it with a live demo and repo link") → **Vote:
rate projects on a 1 to 5 scale**. Peer voting by ~65 builders, with a required Live URL, reorders the
priorities — so the second pass is about what a stranger can open on a laptop:

- **The page no longer needs a wallet, a faucet or a paste to show something.** It boots read-only against the
  testnet RPC (`JsonRpcProvider`; reads never depend on the wallet's provider), and when *nothing* is
  configured it plays `web/demo-match.json` — 21 frames of a real match executed against the patched bytecode
  in a local EVM (`script/record-demo.js`; deterministic — re-running reproduces the file byte-for-byte apart
  from the timestamp). Each frame carries its block, its gas, both players' state and the fact it minted.
- **Honest labelling beats a fake demo.** The preview header reads `Preview · 20 recorded txs, 1,532,906 gas ·
  nothing signed, nothing spent`; `verify()` on a recorded UID says there is no chain to answer it; clicking a cell says it is
  a recording instead of pretending to move. The failure mode this replaces is visible in the Blitz feed
  itself: another team's `Live` link is `http://localhost:3000/`.
- **A measured fee counter** (`txs · gas · ≈MON`) computed from receipts inside `fire()` — deliberately not a
  number from a slide, because this sandbox cannot reach `testnet-rpc.monad.xyz` to price gas honestly.
- `web/hero.png` (1200×630) is generated from the app's own palette by `script/make-hero.py`, which reads its
  numbers out of the recording; `SUBMISSION.md`
  is the paste-ready card; `.monskills.json` records the chain specifics (MONSKILLS is the ecosystem's
  agent-skill library: `npx skills add therealharpaljadeja/monskills`, topics `gas`/`concepts`/`addresses`).
- `web/.nojekyll`, `og:image`, and a data-URI favicon, so a shared link previews as something with a name.

**Verification of this pass:** 10/10 preview steps and 12/12 live steps green in the UI harness
(`keepsake-probe/uismoke.mjs`, which loads the page's *own* module against a fake DOM and mocked ethers — the
same harness that caught the `"0x279f"`-vs-`10143` chain-compare bug in the first version of the fix);
`record-demo.js` reproduces the committed recording exactly; contracts untouched, so the probe suite still
reads **27/27** and `solc` still reports 0 errors.

**Not done, needs a human with repo admin:** GitHub Pages could not be enabled from this session —
`gh api -X POST repos/…/pages` returns `403 Resource not accessible by integration` (the token has contents,
not admin). Until someone sets Settings → Pages → `/web`, the "Live" field has nowhere to point.

### Third pass — the interface, to a brief (`AGENT_UI.md`)

`AGENT_UI.md` arrived from main mid-session and is the design law for this repo, so the restyle was executed against
its text rather than against taste. What the pass changed, and what it proved:

- **Skin.** `--paper #E4D9C5` / `--ink #1C1914` / `--rule #C4B49A` / `--wax #9B2C2C` / `--moss #3F5C4A` /
  `--gilt #8A6A22`, with `--night #1A2330` reserved for the playfield only and `--stamp` for a pressed button.
  Radius 0 everywhere (the harness asserts it), no gradient, no blurred shadow, no pills, no pure white/black/gray,
  type scale 12/15/19/30, tabular numerals, transitions ≤160 ms with a `prefers-reduced-motion` kill switch.
- **The two-player gap in the brief was already closed** by `paint()`: a living pact is a gilt hairline drawn
  between the real cell centres, and the cell containing the counterparty is framed and labelled. Pieces are
  16×16 *squares* with a paper outline (3:1 against night) — never circles, never glow.
- **A broken pact stays visible.** `Attested` records the scar (`addScar`, deduped by `a|b`, capped at 8) and the
  preview walker does the same, so a betrayal survives on the board in wax after the match has forgotten it.
- **The docket, not a chat log.** Each HonorLog entry is dated (`29.08.2026 · BLK 22`) via `provider.getBlock`,
  kind at 19px in the register voice, parties in mono, then the UID and a `verify()` affordance. The empty state
  is a line of paper, not a sentence of marketing.
- **Deploy is furniture.** The address inputs and the deploy note sit in one `<details>` that `boot()` opens only
  when nothing resolves — the read path is wired before any wallet exists, which the harness now tests first.
- **Two places the brief and reality disagreed, resolved by measurement.** (a) §5 wanted the Pact stamp as a gilt
  fill with paper type: `paper/gilt` is 3.61:1 and `ink/gilt` 3.48:1, both under AA for a 12px label, and §4 itself
  says gilt is emphasis and *never* a fill — so Pact carries gilt as a 2px border on paper (ink/paper 13.9:1),
  while Spare and Shoot keep their fills (5.06:1, 6.35:1). (b) Fonts: §4 permits a Google/IBM CDN "if the network
  allows"; a venue network is exactly where it does not, so the four latin subsets are vendored next to `ethers`.
- **`web/hero.png` was rebuilt in the same identity** (paper sheet, night plate, square seals, dashed wax scar, a
  real docket entry) by a generator that now also audits its own layout for overlaps and clipping.

**Verification of this pass:** `script`-extracted module parses; the DOM harness is green at **10/10 preview and
12/12 live** steps, including "boot wires the READ path before any wallet exists" and "connect upgrades the same
board to signing"; a 46-check stylesheet audit (tokens, ban-list, WCAG pairs derived from each rule's own
`color`/`background`) is clean. **No rendered screenshot exists**: this sandbox has no browser binary and the
Chrome download is blocked, so the visual claims are measurements of the CSS and of the generated PNG, not a
picture of the running page. The check is now repo tooling: **`node script/audit-ui.mjs`** (46 assertions, zero dependencies) — run it after any
visual change, since the brief's rules are the kind that decay silently. Contracts untouched → `verify-fixes.js` still 27/27.

### Fourth pass — the platform and chain briefs (`AGENT_BLITZ.md`, `AGENT_MONAD.md`)

Two more briefs landed on main mid-session. Both were written against *main*, so several of their "Missing" rows
were already closed by the earlier passes; the honest score is therefore a mix of "already true", "genuinely
missing, now fixed", and "the brief is wrong, and here is the measurement".

**Already true when the brief was written** (nothing to do, but worth naming, because these are the rows a
judge's agent would check first): public testnet RPC for reads via `JsonRpcProvider` (no localhost RPC, no CDN —
`ethers` and the woff2 subsets are vendored); addresses baked through `web/addresses.json` + `?world=&log=&block=`;
`wallet_addEthereumChain` with exactly the §8 payload, tried after a `wallet_switchEthereumChain` and explained in
the log when refused; `honor.on("Attested")` rather than any `newPendingTransactions`/indexer path; subscriptions
plus a 2 s `viewPlayer` poll instead of a 256-cell sweep; `ethers` v6 kept rather than rewritten to viem+wagmi;
match identity on `block.number` + `prevrandao`, which the brief explicitly warns must not be "fixed" to
`block.timestamp` at second granularity.

**Genuinely missing, now fixed:**

| Brief row | What changed |
|---|---|
| `AGENT_MONAD` §1 — *charged gas is `gas_limit`* | `GAS_CAP` per verb in `fire()` (`spawn 90k · move 45k · pact 420k · spare 380k · shoot 380k · sealMe 300k`), each the **cold** cost measured in `web/demo-match.json` plus ~20 %. The mined line now prints `290,077 of 380,000 gas`, so refusing the wallet's pad is visible on stage rather than assumed. |
| §2 — *`eth_getLogs` ranges are capped near 1000 blocks* | The back-fill's `latest - 20000` default became `latest - 900`, started from the deploy block when `addresses.json` supplies one, and wrapped so a refused wide range **retries narrow** and says so. Before this, a spectator tab on a shared address could hang the whole board on one timeout. |
| §2 — *wait for the receipt before the next verb from the same wallet* | `fire()` takes an `inflight` lock (buttons dim via `body.busy`) and releases it in `finally`. This was a real bug at the first attempt: the lock was taken *outside* the `try`, so a throw wedged it — the DOM harness caught it on the very next run, which is the argument for having a harness at all. |
| §3 — *`foundry.toml` has holes* | `[rpc_endpoints] monad_testnet/monad_mainnet` and `[etherscan] monad_testnet = { key = "-", chain = 10143, url = "…/api", browser = … }`; the `monad = "${MONAD_RPC}"` alias is kept for continuity. `Deploy.s.sol`'s header now carries `--legacy --gas-estimate-multiplier 120 --verify`, with the reason for each flag. Neither forge command could be **executed** here (no Foundry, and the testnet RPC is unreachable from the sandbox), so `--verifier sourcify` from README §Deploy stays as the route already documented and the `[etherscan]` entry as the MonadVision alternative. |
| `AGENT_BLITZ` §4 — *README for voters* | A `## Try it in 60 seconds` section in their shape, with the `Live / World / HonorLog / Network / RPC` header block up top and the two address TODOs made impossible to miss. |
| `AGENT_BLITZ` §2 — *~400-char card copy* | SUBMISSION §2 now leads with the short blurb, the one-line Monad hook and the stage closer, and keeps the long numbers-first paragraph for fields that accept it. Deliberate deviation: the brief's blurb says "pact, spare, or shoot — each mints an attestation"; in this contract a plain kill mints **nothing**, and the sentence that survives scrutiny is the one that says so. |

**Where the brief and the build disagree:** `AGENT_BLITZ` §0 puts the freeze at ~18:00/18:30 from Luma memory
while the event listing says 17:00/17:30 — the repo keeps the earlier pair *and* adopts the brief's rule that
the real deadline is the Devnads submit button, not the room's agenda. §1's "one Monad hook — a real number" is
served by `303 ms` measured on mainnet via the public stats mirror rather than docs' `~10,000 TPS`, which this
match demonstrably does not exercise; an audit check fails if a borrowed TPS number ever enters the pitch files.

**Both briefs are now executable:** `node script/audit-ui.mjs` (46 checks: tokens, ban-list, WCAG per rule) and
`node script/audit-platform.mjs` (37 checks: the add-chain payload against §8, caps against the recording, the
bounded window, the lock's `finally`, foundry endpoints, no localhost anywhere in `web/`, README/SUBMISSION
placeholders, `.monskills.json` agreeing with `foundry.toml` on chain id). The platform audit was negative-tested
— inflate a cap to 9,000,000 and remove the `finally`, and it reports exactly those three violations — so its
green result means something. What neither script can do is the P0 list that requires a human and a network:
claim the event's MON, deploy, `setWorld` confirmed on the explorer, source-verified, Live opened on someone
else's phone, and the submission form filled.

---

## Appendix A — file-by-file map (post-fix)

| File | Read it as | Watch out for |
|---|---|---|
| `contracts/HonorLog.sol` | append-only record store with exactly one writer, pinned write-once | the ABI *shape* of `verify()` (7 outputs) — the UI's `LOG_ABI` string and `test/Keepsake.t.sol` must move with it |
| `contracts/World.sol` | rulebook + attestation trigger, nothing else | `SPARE_WINDOW` couples the rules to the demo choreography (wind **before** you pact); `owner` gates `startMatch` |
| `test/Keepsake.t.sol` | the guards, executable | `_happyPath()`'s ordering is load-bearing; `_parkAdjacent()` spends real `move` txs |
| `script/Deploy.s.sol` | the only place `setWorld` is guaranteed to run, now also the addresses handoff | needs `fs_permissions` for `web/addresses.json`; deploy order is still HonorLog → World → setWorld |
| `web/index.html` | event-fed board, chain-pinned, revert-decoded | still a 2 s poller, not an indexer; `WORLD_ABI` error fragments are what make the reverts readable |
| `web/vendor/ethers.min.js` | offline dependency, 490 KB | regenerate with `npm i ethers@6.13.4 && cp node_modules/ethers/dist/ethers.min.js web/vendor/` |
| `web/monad-crash-course.html` | standalone, zero coupling | nothing |
| `HANDOVER.md` | intent + a v2 amendment banner on top | §6's beat order is the current one; the older prose in §2/§5 was corrected in place, not appended |
| `README.md` | the public face: rule table, testnet-only deploy, verification | keep the rule table honest if a guard is ever loosened |

## Appendix B — reproducing the runtime evidence

Harness kept out of the repo (product is frozen): `/home/user/keepsake-probe/evm.js`.

```bash
mkdir -p /tmp/probe && cd /tmp/probe && npm init -y
npm i solc@0.8.24 viem @ethereumjs/vm@7 @ethereumjs/common@4 @ethereumjs/block@5 \
      @ethereumjs/tx@5 @ethereumjs/util@9 @ethereumjs/statemanager   # pins matter: tx@8/vm@10 = API drift
cp /home/user/keepsake-probe/*.js .
node evm.js            # pre-fix behaviour, 21 probes: the findings, as observed
node verify-fixes.js   # post-fix behaviour, 27 probes: guards revert with their own selectors,
                       #   demo beat still mints [pact, spare, betrayal], cross-match betrayal is gone,
                       #   and every numeric assertion in test/Keepsake.t.sol is checked against execution
```

A third script, `uismoke.mjs`, loads the **page's own module script** into a fake DOM with a mocked
`BrowserProvider`/`Contract` (no browser, no wallet) and drives it: connect → wire → Spawned back-fill →
click a body to target it → fire a verb → force a revert → `verify()` a good and a bad UID. 14/14 steps
green. It is worth running after any UI edit, because it caught a bug *in the fix itself*: `ensureChain()`
compared the RPC's `"0x279f"` to the number `10143`, so every connect would have re-prompted a chain switch.

`evm.js` and `verify-fixes.js` both read `/home/user/keepsake/contracts/*.sol` directly, so they re-verify
whatever is in the tree — including a partial revert of one of these patches. Neither script is a substitute
for `forge test` (no cheatcodes, no invariant fuzzing); they exist because `forge` cannot be installed in this
sandbox and the claims still needed to be *executed* rather than argued.

Notes so you don't lose an hour to plumbing: `forge`/`foundryup` are **not installable in this sandbox** (`foundry.paradigm.xyz` and `release-assets.githubusercontent.com` are blocked), and `esm.sh` is blocked too — both verified with `curl (35)`. `registry.npmjs.org` and `api.github.com` work, which is why the solc + ethereumjs route is available. Two gotchas that bit me, both in the harness not in the contracts: `vm.block` is undefined until you assign a `Block` explicitly, and `vm.runTx` needs `opts.block` per call or every tx executes in one block (which silently turns `startMatch()` into a no-op and makes `currentMatch` look stable).
