# KEEPSAKE

A 16×16 on-chain arena. **The World is the only attester.** You cannot certify yourself — you can only be witnessed.

Live: `https://TODO` (GitHub Pages on this repo's `web/` — see SUBMISSION.md §4) · World: `0xTODO` · HonorLog: `0xTODO`
Network: **Monad Testnet**, chain id `10143` · RPC: `https://testnet-rpc.monad.xyz` · Explorer: `https://testnet.monadvision.com`

The two `TODO`s are filled by the commit `script/Deploy.s.sol` writes: they belong in `web/addresses.json` *and*
here, and both must agree before anyone pastes the Live URL into a submission form.

## Try it in 60 seconds

1. Wallet on **Monad Testnet** (10143), some MON. The page adds the network for you on Connect if MetaMask is
   missing it — this is not a theoretical claim: it was exercised on a wallet whose hand-added row had an empty
   Chain ID (so it sat in *Manage networks* but never appeared in the picker). Connect → MetaMask's own
   `wallet_addEthereumChain` prompt → chip reads `Monad testnet 10143 · the world is the only attester`, with no
   manual typing. If a manual entry is refused as a duplicate chain id, select MetaMask's built-in
   `Monad Testnet` row rather than creating a second one — and never point the *mainnet* row (143, real MON) at
   testnet values.
2. Open the Live URL, **Connect**, **Spawn**.
3. Second wallet, same page, **Spawn**. If you do not see them, paste their address into **Watch**.
4. Stand on adjacent cells. **Pact** → **Spare** (or **Shoot**).
5. A UID appears in the docket. Paste it into `verify()` — in the page, or in the explorer's Read tab.

Nothing on the page needs a wallet to *look*: with no wallet and no addresses it plays a recorded match
(`web/demo-match.json`) and labels itself as exactly that.

You cannot attest yourself. Spare and betrayal are facts that outlive the match.

- `pact` — one-way, instant. A declares trust in B. B never agreed.
- `spare` — you had the shot; you didn't take it. UID mints in that tx.
- `shoot` — if you had a pact on them, this is `Betrayal` and `refUID` points at the Pact.

Portable primitive: any later contract can `HonorLog.verify(uid)` — and it now returns the
`attester`, so a verifier can require provenance, not just existence.

## The rules the contract actually enforces

Guardrails, so the "facts" are facts and the demo can't be bricked from outside:

| Rule | Enforcement |
|---|---|
| Only the World attests | `attest()` is `only-world`; `setWorld()` is **write-once** (`WorldAlreadySet`) so the deployer can never re-point the attester and forge a fact |
| A `spare` must be real | the victim has to be at `≤ SPARE_WINDOW` (2) hp **and still armed**, else `NotKillShot()`. You cannot mint `spared` by clicking a healthy neighbour |
| A pact belongs to one match | `pactMatch[uid]` is stamped at mint; a shot only becomes a Betrayal if that pact was made in *this* match, so `refUID` never dangles into an old match |
| A pair holds one live pact | second `pact()` reverts `AlreadyPacted()` (it used to stack attestations and orphan a UID) |
| Conduct is rollup, once | `sealMe()` reverts `AlreadySealed()` per (player, match). Optional — the demo never needs it |
| Nobody else can rotate the arena | `startMatch()` is owner-only (`NotOwner()`); on a public testnet an open one lets any wallet freeze every live player |
| Honoured pacts are reversible | sparing someone you had pledged to bumps `pactKept`; betraying *that* pact takes the credit back, so "kept" and "broke" can't both be claimed |

Deliberately **not** enforced: a kill writes no attestation (only a *betrayed* kill does). See
`DEEPDIVE.md` §C2/§6 — it is a position, not an oversight: the log records what cost the actor something.

## Deploy (Monad testnet, chain id `10143`)

```bash
forge install foundry-rs/forge-std
export PRIVATE_KEY=0x…            # foundry reads this env var; no --private-key flag

forge script script/Deploy.s.sol:Deploy --rpc-url monad_testnet --broadcast \
  --legacy --gas-estimate-multiplier 120
```

`DEPLOY.md` is the full runbook: wallet and faucet order of operations, what to confirm in the explorer after
broadcast, source verification, publishing, and the two-profile rehearsal.

`monad_testnet` is the alias in `foundry.toml` (10143). `--legacy` because 1559 estimation is flaky on the
testnet endpoint, and the multiplier is the only padding to allow: **Monad charges `gas_limit`, not `gas_used`**,
so a wallet's generous default is money. The UI already sends tight caps per verb (measured cold costs in
`web/demo-match.json` plus ~20%). `export MONAD_RPC=…` still works — `monad = "${MONAD_RPC}"` remains an alias.

That prints both addresses, writes `web/addresses.json` (the UI loads it automatically — no
pasting at the projector), and prints a ready-to-open URL with the addresses in the query string.

Faucet: https://faucet.monad.xyz · explorer: https://testnet.monadvision.com
Use the **testnet**. Mainnet is live (chain id `143`) and MON there is real money; this app is gas-only by design.

Source-verify so judges can call `verify()` themselves in the explorer:

```bash
forge verify-contract $HONORLOG contracts/HonorLog.sol:HonorLog \
  --chain 10143 --verifier sourcify --verifier-url https://sourcify-api-monad.blockvision.org
```

## Demo modes (no wallet required to look)

`web/index.html` picks its source in this order and prints which one it is using, in the header:

| Mode | Trigger | What it means |
|---|---|---|
| **live** | wallet connected + addresses resolved | reads over the testnet RPC, writes signed by you |
| **spectate** | addresses resolved, no wallet | read-only board: same events, same `verify()`, nothing to sign |
| **preview** | nothing configured | plays `web/demo-match.json` — a match recorded from *this* source in a local EVM, labelled "nothing signed, nothing spent" |

`script/Deploy.s.sol` writes `web/addresses.json`, so a deployed repo is a shareable link with no paste step.
Regenerate the recording after any rule change with `node script/record-demo.js` (deps in that file's header),
because the card copy in `SUBMISSION.md` and `web/hero.png` quote its numbers.

## Play it

```bash
python3 -m http.server 8765 --directory web
```

Two browser profiles (or one profile + a second wallet) = two players. `web/vendor/ethers.min.js`
is committed, so the page works with **no network** — no CDN between you and the demo.

Click a cell to move (1 Chebyshev step), click a body to target it, then Pact / Spare / Shoot.
`Spare` needs the other player wounded and armed, so **wound them before you pact them** — the
first shot after a pact is the betrayal. Click any UID in the log to run it through `verify()`.

## Tests

`forge test` runs `test/Keepsake.t.sol`: the demo path, the `refUID` chain, and one regression per
guard above.

## Submission

`SUBMISSION.md` holds the paste-ready hackathon card (copy, measured numbers, links) and the checklist that
makes the Live URL real. The 1200×630 image is generated, not designed by hand: `python3 script/make-hero.py`
reads the recording, refuses to overlap its own lines, and fails the build if a number would be invented.

## Interface

The visual identity is prescribed by `AGENT_UI.md` (on `main`): a canal-city notary wired to a live match —
paper chrome, the playfield the only night surface, seals instead of sprites, radius 0, five chromatics
(paper, ink, wax, moss, gilt) and nothing else. The HonorLog renders as a dated docket of instruments, and
`verify()` as a definition list rather than a blob of JSON.

Re-verify the skin with `node script/audit-ui.mjs` — the brief's ban-list is encoded there, because a design rule
nobody checks is a design rule that decays. Type is **vendored, not CDN'd** (`web/vendor/fonts/`, ~88 KB of latin subsets: Newsreader for the register
voice, IBM Plex Sans for chrome, IBM Plex Mono for docket data), for the same reason `ethers` is vendored:
a captive portal that kills one request must not restyle the demo mid-pitch. No framework, no build step.

## Pitch folio

`web/deck.html` is the talk: eleven slides, paper chrome and a night board like the app, arrow keys / swipe / `F`
for fullscreen, `#n` deep links, and `@media print` turns it into a stackable PDF. Same vendored fonts, no
framework, no build step, and it is checked by the same identity audit (`node script/audit-ui.mjs web/deck.html
--projection`). Serve it with the app and it lives at `/deck.html` — useful as the thing you project when the
wifi is bad, and as the fallback if a laptop dies.

## Pitch line

> A future DAO can require `spared ≥ 1` without me building that DAO. We didn't ship a leaderboard.
> We shipped a factory for facts about people.
