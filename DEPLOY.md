# DEPLOY — Monad testnet, step by step (Monad Blitz Amsterdam, 2026-08-29)

Every step here needs a laptop with network. It cannot be done from the Arena sandbox: there is no Foundry in
it, and its egress to `testnet-rpc.monad.xyz` fails (`SSL_ERROR_SYSCALL`). So nothing in this file is claimed as
*done* — the repo's own numbers come from executing the patched bytecode in a local EVM, and this runbook is how
you make them true on the chain the event funds. Budget ~35 minutes, start with the faucet, which is the long pole.

## 0 · What the code already handles, so you don't configure it

- **No `startMatch()` needed after deploy.** `World`'s constructor calls `_newMatch()`, so a live match exists
  the moment the tx lands and `spawn` works immediately. `startMatch()` is only how you rotate to a fresh board
  (owner-only) between pitches — and rotation resets positions and scores while `verify(uid)` keeps answering,
  which is the scene the whole deck is built on.
- The UI adds/switches the network (`wallet_addEthereumChain`, chain 10143), refuses mainnet 143 with a visible
  header, sends **tight `gasLimit` per verb**, keeps **one write in flight per wallet**, scans **bounded** log
  windows, and falls back to preview mode with no network at all. No build step, no CDN.

## 1 · Wallet + testnet MON — do this first (10 min)

1. MetaMask or Rabby. **Create a fresh account** for the event: testnet genesis was reset **2025-12-16**, so any
   balance on an earlier testnet address is gone, and the docs discourage keys that have sent pre-155 transactions.
2. Claim MON **once**, for the deployer: **`blitz.devnads.com` → Amsterdam → the event's MON claim** (approved
   attendees). It is capped at **one 50-MON claim per whitelisted email** — a second attempt answers *"You have
   already claimed your 50 MON tokens for this event"* — and it is the wallet the platform associates with your
   entry, which is what "I funded both demo wallets" means. The public faucets (`https://faucet.monad.xyz`,
   `https://testnet.monad.xyz/faucet`) are the fallback if the in-app claim is down. Both drip from one
   distributor, `0xF2bD4Aaa1065d7C44CdFe0537308d41793Abe167` — 2,132 identical 50-MON transfers across 253 days.
3. **Fund player B by transferring 2 MON from the deployer.** There is no second claim to make, and a faucet rate
   limit is the last thing you want standing between you and a two-chair demo. 2 MON is 16× what B's whole role
   in a match costs (≈0.12), the transfer costs 0.0022, and the deployer keeps 48 for the deploys.
   - Paste the **full 42-character** address (MetaMask → account details → copy). Never retype it, and never
     trust a `0x1234…abcd` display: eight hex digits is 4 billion collisions across 872k testnet accounts.
   - **Confirm the network picker reads Testnet / 10143 before you sign.** Mainnet sits in the same dropdown,
     and mainnet MON is real money.
   - Leave MetaMask's suggested gas. Blocks are ~300 ms, so it lands in about a second.
   - Expected: deployer at **1 outgoing**, B at **1 incoming of 2 MON**. Read both on the explorer — it is also
     a free test that the wallet can sign, estimate, and land a transaction, the three things that otherwise
     first fail live on stage.
4. Reads are free; everything else pays at the testnet's
   **102 Gwei** base fee (base 100 + 2 tip), measured from the transfer above: 21,165 gas cost **0.00215883 MON**
   = `gas × 102 Gwei` exactly, so no fudge factor is needed to turn our gas table into money.

   | what | gas | ≈ MON |
   |---|---|---|
   | `move` | 12,778 | 0.0013 |
   | `spawn` | 57,165 | 0.0058 |
   | `pact`, cold | 338,508 | 0.0345 |
   | the whole 20-tx match | 1,532,906 | 0.1564 |
   | all three deploys + `setWorld` | ≈2,060,000 | 0.2101 (0.2521 at the 120% multiplier) |
   | same match, every verb at its **cap** | 3,996,200 | 0.4076 |

   One drip is **50 MON**, so deploy + ten full matches is about 3.7 MON and 46 remains. Fund both and stop
   thinking about balances. A spawn should put `≈0.00583083 MON` in the page's fee line — if it ever reads
   `≈0.00000000`, no receipt was read, which is a bug to report, not cheap gas.
5. Network, added by hand or by the page: chain id **10143** · RPC `https://testnet-rpc.monad.xyz` ·
   symbol **MON** (18 decimals) · explorer `https://testnet.monadvision.com` · `wss://testnet-rpc.monad.xyz` if a
   tool wants WS. Venue wifi congested → `https://rpc-testnet.monadinfra.com` (20 rps, **no batching**).
6. `export PRIVATE_KEY=0x…` in the terminal only — Foundry picks it up, so no `--private-key` flag is needed.
   Never in a file, never committed, never in a commit message. **The deployer is the owner** of both contracts,
   so keep it reachable all day: its only two levers are `startMatch()` and `HonorLog.renounceOwner()`.

## 2 · Toolchain + deploy (2 min)

```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup      # need v1.8+
git clone https://github.com/knarayanareddy/keepsake && cd keepsake
git checkout arena/01a04cd6-keepsake                            # the branch with the fixes and the deploy config
forge install foundry-rs/forge-std                              # the repo ships no lib/
forge build && forge test -vv                                   # 16 tests, runs offline

forge script script/Deploy.s.sol:Deploy --rpc-url monad_testnet \
  --broadcast --legacy --gas-estimate-multiplier 120
```

Three transactions, in the order that is the only one that works: `new HonorLog()` → `new World(log)` →
`log.setWorld(world)`. If you ever deploy by hand instead, **skipping `setWorld` is the one silent failure**: every
`attest()` reverts `NotWorld()`, the game plays perfectly, and the log stays empty.

`--legacy` because 1559 estimation is flaky on that endpoint; the multiplier is the only padding to allow, since
Monad charges `gas_limit` and a wallet's default pad is paid in full. Prefer your own RPC? `export MONAD_RPC=…`
and `--rpc-url monad` still works (the `${MONAD_RPC}` alias is kept in `foundry.toml`).

## 3 · Four confirmations (5 min — this is the part that wins votes)

```bash
export WORLD=0x… LOG=0x…                                    # from the script output
cast call $LOG   "world()(address)"          --rpc-url monad_testnet   # must equal $WORLD
cast call $WORLD "currentMatch()(bytes32)"   --rpc-url monad_testnet   # must be a non-zero hash
cast call $WORLD "viewPlayer(address)" $WALLET_A --rpc-url monad_testnet   # joined = false, alive = false
```

1. `HonorLog.world() == World` — the attester pin landed, so attestations can be minted at all.
2. `currentMatch()` is a real hash — the board is live without anyone touching it.
3. Both addresses exist on `testnet.monadvision.com`, `setWorld` shows as a mined tx, constructor args are visible.
4. Send one `spawn` from the page and compare its **receipt**: gas *used* should land near the recorded
   23,080–57,164 (same EVM execution), and the explorer will show *limit vs used* — that gap is the pad we refuse
   to pay. If used diverges a lot from the recording, say "the numbers are from a local EVM run on this bytecode"
   out loud; do not hand-edit `web/hero.png`, regenerate it (`python3 script/make-hero.py`).

## 4 · Source verification (3 min)

```bash
forge verify-contract $LOG   contracts/HonorLog.sol:HonorLog --chain 10143 \
  --verifier sourcify --verifier-url https://sourcify-api-monad.blockvision.org
forge verify-contract $WORLD contracts/World.sol:World       --chain 10143 \
  --verifier sourcify --verifier-url https://sourcify-api-monad.blockvision.org
```

Alternatives if Sourcify is having a day: re-run the deploy script with `--verify` (uses `[etherscan]
monad_testnet` → MonadVision, key `"-"`), or the etherscan-style endpoint `https://api.monadscan.com/api` (needs a
key). All three are recorded in `.monskills.json`. This is not vanity: verified source is what lets a judge call
`verify(bytes32)` in the explorer's Read tab and check our central claim without trusting a single word of the deck.

## 5 · Publish (5 min)

```bash
cat web/addresses.json                                  # { world, log, block }, written by the deploy
git add web/addresses.json README.md && git commit -m "deployed: Monad testnet addresses" && git push
```

Then fill README's three header TODOs (`Live`, `World`, `HonorLog`) — `node script/audit-platform.mjs` fails if
`addresses.json` and the README stop agreeing, which is the failure mode of a card that links to a dead board.

GitHub Pages: Settings → Pages → *Deploy from a branch* → `main` (or the branch you deploy) → folder `/web` →
Save. Two clicks; the API route returns `403` for a contents-scoped token, which is exactly what happened here.
Then open `https://<user>.github.io/keepsake/` on **a phone you are not holding**: it should boot in **read-only**
mode, paint the board, and print a `scanned Spawned, …` line. That is the state a voter sees, so it must not be
the preview recording — if it still says `Preview ·`, the address file isn't being served.

If `addresses.json`'s `block` ends up *after* the World's real deploy block (Foundry's `block.number` is captured
at broadcast start, so it usually lands earlier, which is harmless), lower it a few hundred and push: a wide scan
window never hurts, a narrow one silently hides the first players.

## 6 · Rehearse the two-profile demo (5 min)

Two Chrome profiles on the Live URL. A spawns, B spawns, A sees B within ~2 s (subscriptions + the poll) — or via
**Watch**. Then: move adjacent → **Pact** → **Spare** on a *full-health* target so the room sees `NotKillShot` →
**Spare** on a wounded one (mints) → **Shoot** (the BETRAYAL row, `refUID` pointing at her own pact) → click
**verify()** in the docket, then paste the same uid into the explorer's Read tab. Then kill someone and show that
**nothing** appears in the log.

Want a clean board for the next pitch? `cast send $WORLD "startMatch()" --rpc-url monad_testnet --legacy
--private-key $PRIVATE_KEY`. Positions and scores reset; the four records still resolve. Say that sentence while
doing it — it is the entire product in one action.

## 7 · Freeze, submit, and afterwards

Submit on `blitz.devnads.com` **before** lining up to talk: the submit button is the deadline, not the agenda
(the event listing says 17:00 freeze / 17:30 submission; `AGENT_BLITZ.md` remembers ~18:00 — work the earlier pair).
Paste `SUBMISSION.md` §2: short blurb, hero image, Live, Code. Record the 60-second clip last, when the thing you
record is the live board.

Afterwards: list the page in the platform's **Testnet Directory** (it outlives the submission feed), and only once
the demo is safely done, `HonorLog.renounceOwner()` is the closing flourish — it makes the write-once attester pin
irreversible. Never before you've finished rehearsing rotation.
