# KEEPSAKE — submission sheet (Monad Blitz Amsterdam, 2026-08-29)

This file is the paste-ready content for the Blitz platform (`blitz.devnads.com` → Amsterdam → ENTER → submit),
plus the two-minute checklist that makes the **Live** link real. The platform's own loop is
*Sign up → Build → **Vote: rate projects on a 1–5 scale** — so this is written for a room of ~65 builders
clicking a link on a laptop, not for three judges reading a repo.

---

## 1 · What to paste where

| Field | Value |
|---|---|
| **Title** | `KEEPSAKE — the World is the only attester` |
| **Image** | `web/hero.png` (1200×630, drawn by `script/make-hero.py` from the app's own palette) |
| **Code** | `https://github.com/knarayanareddy/keepsake` |
| **Live** | `https://<user>.github.io/keepsake/` — see §4 for the two commands that make this exist |
| **Demo** | 60-second screen recording of the replay + one live two-wallet match (see §5) |
| **Description** | §2 verbatim; it is written numbers-first because that is what the other submitted Blitz projects do |

## 2 · Card copy (paste this)

**If the field is ~400 characters** (the platform's cards are short — this is the version that fits a phone screen):

> KEEPSAKE is a 16×16 on-chain arena. Pact, spare, or betray — each mints an attestation. You cannot certify
> yourself; the World contract is the only attester. A plain kill mints nothing, so the only facts available
> are ones that cost you something. Close the laptop: `verify(uid)` still says who was spared.

**Monad hook** (one line, and it is the mechanism, not a boast): *sub-second blocks — 303 ms measured average
on mainnet — so a spare becomes a fact in the same breath as the move, not a 12-second ritual elsewhere.*

**Closer, for the stage:** *If my laptop dies, the chain still remembers who was spared.* (Deliberately: the
`tokenURI` SVG stamp stays undone — AGENT_BLITZ §3 files it P2, and poetry out-votes a render.)

**If it takes a paragraph**, paste this instead — numbers-first, because that is what the submitted Blitz cards do:


> **KEEPSAKE** is a 16×16 arena on Monad testnet where the only witness to what you did is the chain itself.
> Two players, five hit points, six rounds, one contract that is allowed to write. You can **pact** (one-way —
> I promise not to finish you; you never had to accept), **spare**, or **betray**. Each of those becomes an
> append-only, soulbound ERC-721 in `HonorLog`, and a Betrayal carries `refUID` pointing at the exact pact it
> broke, so the record proves the betrayal *and* the trust it broke, in one read.
>
> Two contracts, **11,120 bytes of runtime code** (HonorLog 3,425 B, World 7,695 B — 14 % and 31 % of
> EIP-170). A move costs **12,778 gas**; an attested fact — the pact, the spare, the betrayal — costs
> **233k–339k** cold, and the whole 20-transaction match in our recorded game is **1,532,906 gas**: about
> **0.156 MON** at the testnet's measured 102 Gwei base fee — and the UI prints the number it read off your own
> receipts, not off a slide. (Cross-checked on-chain: a bare 21,165-gas transfer cost 0.00215883 MON, which is
> exactly `gas × 102 Gwei`, so nothing here needs a fudge factor.)
>
> The rules are guards, not vibes. `spare` reverts `NotKillShot()` unless the victim is at ≤ 2 hp *and still
> armed*, so "I had the kill shot and chose not to take it" cannot be claimed by someone at full health.
> `HonorLog.setWorld()` is **write-once** and `attest()` accepts exactly one caller — there is no admin path
> to rewrite history, and `HonorLog.renounceOwner()` can freeze that pin permanently. The one owner lever that
> does exist, `World.startMatch()`, rotates the board; it cannot forge a record. `startMatch()` is deployer-gated, so
> nobody on a public testnet can rotate the board out from under you. A kill **deliberately writes nothing**:
> the record you get is the record of a choice, not of a body count.
>
> **16 Foundry tests** pin every one of those behaviours, and 27 runtime probes executed the actual patched
> bytecode to confirm them (`DEEPDIVE.md` §10 has the method and the table). No tokens, no money, no
> framework, no off-chain trust, no server: `web/` is a static directory with `ethers` vendored inside it, so
> the demo survives a venue wifi that kills a CDN. If the chain is unreachable, the page detects it and
> plays a **match recorded off this exact source in a local EVM** — 21 frames, real coordinates, real UIDs,
> labelled "nothing signed, nothing spent" instead of pretending.

## 3 · Why Monad (the honest version)

- The attestation *is* the product, and it needed a chain where an attested write costs less than a coffee:
  338,508 gas for a pact on Monad testnet is the whole scene.
- 16×16 board, one transaction per step: this is a workload of many small, parallel, non-conflicting writes.
  Parallel execution and ~300 ms blocks are not a decoration here, they are what makes "the board moved"
  feel like a game and not a form submission.
- Testnet-only, deliberately: `chainId 10143` is pinned in the UI, mainnet (143) is refused with a visible
  header warning, and there is nothing to buy.

## 4 · Make the Live link actually work (before 17:30)

`DEPLOY.md` (repo root) is the step-by-step: wallet → MON → deploy → four explorer confirmations → verify →
publish → rehearse. This section is the short version of the same list.

```bash
forge install foundry-rs/forge-std && forge test -vv                     # 16 tests
export PRIVATE_KEY=0x…                                  # foundry reads the env var
forge script script/Deploy.s.sol:Deploy --rpc-url monad_testnet --broadcast \
  --legacy --gas-estimate-multiplier 120 --verify        # writes web/addresses.json
git add web/addresses.json && git commit -m "deployed: testnet addresses" && git push   # the zero-config handoff
```

The flags are not decoration (`AGENT_MONAD.md` §3): `monad_testnet` is chain **10143**, the network the event's
MON claim funds; `--legacy` because 1559 estimation is flaky there; the multiplier is the *only* padding to allow,
since Monad charges `gas_limit`; `--verify` posts the source to MonadVision through `[etherscan]` in
`foundry.toml`. README §Deploy carries the Sourcify command (`--verifier sourcify
--verifier-url https://sourcify-api-monad.blockvision.org`), which is the one this repo has already checked;
both routes could not be *run* from this sandbox, so verify once at the venue and keep whichever answers. Keep the commit: `web/addresses.json`
carries the deploy **block**, which is what widens the UI's log scan past its 900-block default.

Then serve `web/` as the site root. Either:
- **GitHub Pages** — Settings → Pages → Source: *Deploy from a branch* → branch `main` (or this branch) →
  folder `/web` → Save. CLI equivalent (needs admin scope on the token; the Arena sandbox got `403`):
  `gh api -X POST repos/knarayanareddy/keepsake/pages -f build_type=legacy -f source[branch]=main -f source[path]=web`
- or `vercel --prod` in `web/` (no build step: one HTML file, vendored `ethers`, vendored woff2 subsets, one JSON).
- The UI follows the repo's own design brief, `AGENT_UI.md`: paper chrome, night playfield, square seals,
  radius 0, and a HonorLog that reads as a dated docket instead of a chat log.

Then confirm the two things the platform itself marks as fatal: **Live opens on a phone you are not holding**
(a voter's own device, no builder present), and **Live is never `http://localhost`** — another Amsterdam card
in the feed points at `localhost:3000` and is therefore unwinnable. The `Devnads` submit button, not the Luma
agenda, is the real freeze: submit, *then* line up to talk.

Then confirm the four things a voter will hit: the board paints without a wallet (**read-only mode** via
`JsonRpcProvider`), `verify()` answers for a UID from the Read tab of the explorer, `Spawned` from another
laptop shows up on this one, and nothing on the page asks for a private key.

Faucet for the second wallet: the Blitz platform's own step 1 (*"get approved and claim your testnet MON
tokens"*), or `https://testnet.monad.xyz/faucet`. Testnet only — the deck claims no spend.

## 5 · 60-second demo (and the 3-minute pitch, 18:00)

1. Open the Live URL on the projector. It boots in **read-only** or **preview** mode — say so out loud: *"no
   wallet needed to look; that is the point."*
2. Press **▶ play** on the REPLAY panel: ALICE and BOB spawn at coordinates the chain dealt them, walk into
   adjacency one transaction at a time, trade three shots, and now both sit at 2 hp — inside the spare window.
3. *"Now the part that is a rule, not a story."* Click **Spare** on a **full-health** opponent → the UI prints
   `NotKillShot` — "not a kill shot — they must be ≤2 hp and still armed". Then click it on a wounded one →
   a PACT/SPARE pair mints. **The chain refused to flatter us.**
4. Pact → Spare → Shoot. Point at the **BETRAYAL** row: `refUID` is her own pact. `verify()` in the explorer's
   Read tab returns `attester = the World`, `ok = true` — after the match rotated, positions reset, that did not.
5. Kill someone. Show that **nothing appears in the log.** *"A kill is not an achievement here. Only a choice is."*

**Backup line if anything dies:** the page still plays the recorded match with no network at all, because
`ethers` is vendored and `demo-match.json` is committed. The fallback is the demo, not a compromise.

## 6 · Anticipated Q&A

Full list in `DEEPDIVE.md` §6; the three most likely here:

- *"Why not EAS directly?"* — EAS is the right shape and the wrong dependency for a day: a revocation path and
  an registry to coordinate. `Attested`'s payload is deliberately EAS-shaped (`schema, subject, attester,
  other, refUID, kind`), so the migration is a contract swap, not a rewrite.
- *"Anyone can call `spawn` and grief your match."* — They can join, they cannot rotate: `startMatch` is
  owner-gated, duplicate live pacts revert, and every verb needs adjacency + hp + ammo, so a griefer pays
  for the privilege of being a fifth dot on a 16×16 board.
- *"Isn't this Civic Pulse — on-chain incident reporting?"* — Closest thing on the homepage, and the shape is
  opposite. There is no queue, no admin, no reporter role and nothing to triage: the only way a fact enters the
  log is that **you** gave up a kill shot or spent a pact, and the contract refuses to let you write one about
  yourself. Reporting has an authority; this has a counterparty.
- *"Why no indexer?"* — The Monad docs say to use one rather than hammer `eth_getLogs`, and that is right for
  production. For a seven-hour build the honest read of the same docs is: subscribe, poll a handful of
  `viewPlayer` calls every 2 s, and scan a *bounded* log window (900 blocks, widened by the deploy block). An
  indexer is a second product and a second thing that can be down on stage.
- *"Why testnet and not mainnet 143?"* — The event funds testnet MON and the platform's own step 1 is a testnet
  claim; the UI pins 10143 and refuses mainnet with a visible warning rather than silently reading the wrong
  state. If the organisers announce mainnet is expected, the change is one constant plus a deploy.
- *"The attestation is free, so what stops spam?"* — Nothing, and that is intended: a *fact* must stay free.
  What stops the lie is that the fact is now constrained by state — you cannot attest a mercy you did not
  have to grant.

## 7 · After the pitches

- List the deployed page in the platform's **Testnet Directory** (beta, 83 apps) — submissions expire, directories don't.
- `forge verify-contract` both addresses (or re-run the deploy command with `--verify`) so a judge can call
  `verify()` from the explorer's Read tab without trusting us.
- `.monskills.json` in the repo root records the networks this project touches so an agent picking it up
  starts from the ecosystem skills instead of re-deriving them (`npx skills add therealharpaljadeja/monskills`).

## 8 · Licence

MIT — see `LICENSE`. Per-file SPDX headers match. Fork it, but if you change a rule, the README table and
`test/Keepsake.t.sol` are the two places that have to move with it.
