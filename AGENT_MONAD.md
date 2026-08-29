# AGENT BRIEF — Monad docs vs this build

Source of truth: [docs.monad.xyz](https://docs.monad.xyz/) (Deployment Summary, Testnet, RPC differences, Best practices).  
Use with `HANDOVER.md`, `AGENT_UI.md`, `AGENT_BLITZ.md`.

**This file wins on chain IDs, RPC, gas, logs, and Foundry flags.**

KEEPSAKE does **not** need staking, 7702, 4337, x402, JIT, MonadDB internals, or RaptorCast. Solidity + JSON-RPC is enough. The gaps are **integration**, not architecture.

---

## 0. Which chain (easy to get wrong)

Blitz site: **claim testnet MON**. Default deploy = **Monad Testnet**, not mainnet.

| | Testnet (Blitz default) | Mainnet |
|--|-------------------------|---------|
| Chain ID | **`10143`** | `143` |
| Name | `Monad Testnet` | `Monad Mainnet` |
| Symbol | `MON` | `MON` |
| RPC | `https://testnet-rpc.monad.xyz` | `https://rpc.monad.xyz` |
| WS | `wss://testnet-rpc.monad.xyz` | `wss://rpc.monad.xyz` |
| Explorer | https://testnet.monadvision.com · https://testnet.monadscan.com | https://monadvision.com |
| Faucet | https://faucet.monad.xyz **and** Devnads event claim | — |
| App hub | https://testnet.monad.xyz | https://app.monad.xyz |

Testnet genesis was **reset 2025-12-16**. Old testnet addresses are dead.

**Frontend must `wallet_addEthereumChain` with 10143**, `MON`, testnet RPC, testnet explorer. Wrong chain = silent fail / Ethereum gas.

Confirm with organizers if Amsterdam unexpectedly wants **143**. Do not guess mainnet because “mainnet launched Nov 24 2025.”

---

## 1. Numbers you can say in a pitch (current docs)

- ~**10,000** TPS, **300 ms** blocks, **~600 ms** finality (two blocks). Speculative finality ~300 ms (`Voted`).
- EVM **Fusaka** bytecode. Same address space, typed txs 0/1/2/4. **No EIP-4844.**
- Tx gas cap **30M**. Block **150M**. Min base fee **100 MON-gwei**.
- **Charged gas = `gas_limit`, not `gas_used`.** `cost = value + gas_price * gas_limit`.  
  **Do not** estimate 1M and let MetaMask pad to 2M “for luck” — users pay the pad. Set a tight limit on spawn/move/pact (~200k is plenty for these contracts) or `eth_estimateGas` + small buffer only.
- Cold `SLOAD`/`SSTORE` cost more than Ethereum (8,100 vs 2,100). KEEPSAKE is tiny; ignore unless you stuff SVG into `tokenURI`.
- `TIMESTAMP` is **second** granularity → **3–4 blocks share the same timestamp**.  
  `World._newMatch` uses `block.number` + `prevrandao` — **good. Do not switch uniqueness to `block.timestamp`.**

Official Foundry deploy guide: https://docs.monad.xyz/guides/deploy-smart-contract/foundry  
Verify: https://docs.monad.xyz/guides/verify-smart-contract

---

## 2. RPC / frontend (this is where the demo dies)

From [RPC differences](https://docs.monad.xyz/reference/rpc-differences) and [best practices](https://docs.monad.xyz/developer-essentials/best-practices):

| Topic | Monad behavior | KEEPSAKE action |
|-------|----------------|-----------------|
| `eth_getLogs` | Max range often **1000** blocks; docs recommend **1–10** for speed. Huge ranges timeout. | **Do not** `queryFilter` from block `0` on a public RPC. Index `Spawned`/`Moved`/`Shot`/`Attested` from **deploy block** or `latest - 200`. Prefer `contract.on(...)` + `eth_subscribe` logs. Keep `viewPlayer` poll as backup. |
| Indexers | Docs: use Envio / Graph / thirdweb instead of hammering `getLogs`. | Skip indexer for hackathon. Polling + live subscriptions is the right 7h choice. |
| `eth_subscribe` | **No** `newPendingTransactions`, **no** `syncing`. `newHeads` + logs: yes. | Mempool-choir ideas are **invalid**. `honor.on("Attested")` is fine. |
| `eth_sendRawTransaction` | May **accept** nonce-gap / low-balance txs that Ethereum would reject (async execution). | UI: wait for receipt before the next verb from the **same** wallet. Don’t parallelize pact+shoot from one account. Two wallets in parallel is the Monad win. |
| Nonces | Fast blocks; `getTransactionCount` lags if you spam. | One-in-flight per wallet is enough. If you add keyboard-repeat move: local nonce. |
| `eth_call` / historical | Some RPCs **don’t** serve old state. | Don’t `call` at historical blocks. `viewPlayer` at latest only. |
| Rate limits | Testnet QuickNode **50 rps** (25 for `eth_call`/`estimateGas`). Foundation **20 rps**, **no batch**. | `setInterval(2000)` + a handful of `viewPlayer` is OK. Do **not** poll all 256 cells. |
| Batches | Some endpoints batch max **1**. | Avoid `provider.send` batches. |
| WS | `wss://testnet-rpc.monad.xyz` | ethers `BrowserProvider(window.ethereum)` uses wallet RPC — fine. For event subs without wallet, use WSS. |
| Libraries | Docs: **Foundry v1.8+** with Monad execution network; **viem ≥ 2.40.0**. | ethers v6 via esm.sh is OK for a static page. Don’t “upgrade” to a Next+wagmi rewrite unless time surplus. If you do: viem 2.40+. |

Public testnet RPC: `https://testnet-rpc.monad.xyz` (QuickNode, archive ✅). Fallback: `https://rpc-testnet.monadinfra.com` (20 rps, no batch).

---

## 3. Foundry deploy (fill the holes in this repo)

`foundry.toml` today only has `monad = "${MONAD_RPC}"`. **Set:**

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc = "0.8.24"

[rpc_endpoints]
monad_testnet = "https://testnet-rpc.monad.xyz"
monad_mainnet = "https://rpc.monad.xyz"

[etherscan]
monad_testnet = { key = "-", chain = 10143, url = "https://testnet.monadvision.com/api" }
```

Docs: use **Foundry v1.8+** and enable Monad execution if the guide says so (`foundry` toolkit page).

```bash
forge install foundry-rs/forge-std
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://testnet-rpc.monad.xyz \
  --broadcast \
  --legacy \          # if 1559 estimation is flaky
  --private-key $PK \
  --gas-estimate-multiplier 120
```

After deploy: **verify** on MonadVision (guide in docs). Unverified World looks amateur on a peer-vote card.

**Reserve:** if estimate is huge, you pay that limit. Check the tx on explorer: `gas limit` vs `gas used`.

Create2 / deterministic factory exists on testnet (`0x4e59…956c`) — **not needed** for a one-shot Blitz deploy.

---

## 4. Parallel execution vs this contract (honest)

Monad optimistic-parallelizes **non-conflicting storage**.

- Two players `move` / `pact` on **different addresses** → different mapping slots → **parallel**. Good demo: both mash move, both land in ~300ms.
- `currentMatch` and `matches[id].players++` on `spawn` → **shared write**. Two simultaneous first-spawns can collide and re-execute. Fine; don’t spawn-spam 20 wallets into one counter for a TPS theater.
- Same cell / `shoot` touching victim `hp` → conflict, replay. That’s the game.

**Do not** build a parallelism visualizer. **Do** let two wallets send at once so the room *feels* 300ms.

Shared `HonorLog.nonce++` serializes attestations — OK at hackathon volume.

---

## 5. Wallet / UX (docs: “only RPC URL and chain id”)

- MetaMask / standard EIP-1193. Currency **MON**, 18 decimals.
- EIP-1559 type-2 default. Min tip; `eth_maxPriorityFeePerGas` may return a **hardcoded 2 gwei** (docs: temporary). Don’t overthink fees.
- Pre-EIP-155 accounts: don’t reuse ancient Ethereum keys that sent pre-155 txs (docs discourage). Fresh Blitz wallet is fine.

---

## 6. Out of scope (docs toys we are not using)

x402 proxies, Permit2, EntryPoint 0.6–0.8, P256 precompile, Multicall3, Execution Events SDK / Monode, MCP tutorial, Farcaster miniapp, Privy templates. Using them is a **new product**. Canonical addresses are on the testnet page if you ever need Multicall3 (`0xcA11…`).

---

## 7. Checklist vs current KEEPSAKE repo

| Item | Status | Action |
|------|--------|--------|
| Solidity EVM / no 4844 | OK | — |
| Match id uses `block.number` not `timestamp` | OK | Don’t “fix” to timestamp |
| Tiny contracts ≪ 30M / 128kb | OK | No on-chain HTML app |
| Chain 10143 in UI | **Missing** | `wallet_addEthereumChain` |
| RPC hardcoded testnet | **Missing** | Bake `https://testnet-rpc.monad.xyz` for read/events if needed |
| `getLogs` from 0 | **Risk** | From deploy block / subscribe |
| `newPendingTransactions` | N/A | Don’t add |
| Gas limit = charged | **Risk** | Tight estimate; no 1M defaults |
| Wait receipt per wallet | Partial | Enforce in UI before next verb |
| forge-std / chain_id 10143 | **Missing** | Install + foundry.toml |
| Verify on MonadVision | **Missing** | After broadcast |
| Event indexer | Intentionally skipped | Poll + `on` |
| ethers vs viem 2.40 | Acceptable | Don’t rewrite |
| Mainnet 143 | Only if organizers say so | Default testnet |

---

## 8. Copy-paste for `wallet_addEthereumChain`

```json
{
  "chainId": "0x279f",
  "chainName": "Monad Testnet",
  "nativeCurrency": { "name": "MON", "symbol": "MON", "decimals": 18 },
  "rpcUrls": ["https://testnet-rpc.monad.xyz"],
  "blockExplorerUrls": ["https://testnet.monadvision.com"]
}
```

`0x279f` = 10143.

---

## 9. Pitch accuracy

Say **300ms blocks / ~600ms finality**, not “1 second” or “10k TPS” as something *this* match demonstrates. What you demonstrate: **a spare becomes a `verify(uid)` fact in the same breath**. That’s the docs, felt.
