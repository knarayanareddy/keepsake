# KEEPSAKE

A 16×16 on-chain arena. **The World is the only attester.** You cannot certify yourself — you can only be witnessed.

- `pact` — one-way, instant. A declares trust in B. B never agreed.
- `spare` — you had the shot; you didn’t take it. UID mints in that tx.
- `shoot` — if you had a pact on them, this is `Betrayal` and `refUID` points at the Pact.

Portable primitive: any later contract can `HonorLog.verify(uid)`.

## Deploy (Monad)

```bash
# from a foundry-monad checkout, or:
curl -L https://foundry.paradigm.xyz | bash && foundryup

forge script script/Deploy.s.sol:Deploy --rpc-url $MONAD_RPC --broadcast --private-key $PK
```

Paste the two addresses into the UI (Deploy box). Serve `web/`:

```bash
python3 -m http.server 8765 --directory web
```

Two browser profiles = two players. Click board to move (1 step). Click a body to target. Pact / Spare / Shoot.

## Pitch line

> A future DAO can require `spared ≥ 1` without me building that DAO. We didn’t ship a leaderboard. We shipped a factory for facts about people.
