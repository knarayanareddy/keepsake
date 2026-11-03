# KEEPSAKE review

## 1) Scope and verdict

- Repo: `keepsake`
- Pinned SHA: `1d8c4624e04d40a43951cdbf4098e9ec450802aa`
- Stage: implementation / live-demo prototype
- Runtime: **NOT RUN**

Personally inspected evidence:

- **[S1]** local snapshot metadata: `fleet-hardening-review/evidence/keepsake/snapshot.json` lines 1-106
- **[S2]** snapshot-materialized numbered source: `README.md` lines 1-151
- **[S3]** `contracts/HonorLog.sol` lines 1-147, pinned GitHub fetch
- **[S4]** `contracts/World.sol` lines 1-282, same fetch
- **[S5]** `script/Deploy.s.sol` lines 1-45, same fetch
- **[S6]** `web/index.html` lines 1-896, same fetch
- **[S7]** `test/Keepsake.t.sol` lines 1-204, same fetch

Uninspected boundaries: `DEPLOY.md`, `HANDOVER.md`, `DEEPDIVE.md`, `SUBMISSION.md`, `AGENT_*.md`, `script/audit-ui.mjs`, `script/record-demo.js`, live chain state, wallet behavior, published site contents, and deploy credentials.

**Verdict:** the sampled contracts are coherent, but the inspected browser client has **three confirmed static defects**: the chain guard does not fail closed before wiring or later writes, spectate mode reads player state from the signer-only contract variable, and the board/setup flow is not keyboard/label complete. Additional bounded risks remain around CI scope, deploy metadata drift, deploy/dependency assurance, and irreversible public-chain records.

## 2) Architecture and product boundary

1. **On-chain core:** `HonorLog` is a write-once registry and only accepts writes from `world` ([S3 57-70](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/contracts/HonorLog.sol#L57-L70), [S3 79-118](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/contracts/HonorLog.sol#L79-L118)). `World` owns match state, pact lifetime, spare / betrayal rules, and conduct rollup ([S4 132-265](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/contracts/World.sol#L132-L265)).
2. **Deployment bridge:** `script/Deploy.s.sol` deploys `HonorLog`, deploys `World(log)`, pins `world`, then writes `web/addresses.json` with `world`, `log`, and `block` ([S5 8-41](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/script/Deploy.s.sol#L8-L41)).
3. **Static client:** `web/index.html` resolves addresses from query string / `addresses.json` / local storage, reads over Monad testnet RPC, and writes through an EIP-1193 wallet ([S6 640-722](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L640-L722), [S6 785-893](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L785-L893)).

Visible trust boundaries: Monad testnet RPC and chain `10143` ([S6 252-312](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L252-L312)), wallet-signed writes ([S6 608-627](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L608-L627)), Foundry plus separately installed `forge-std` ([S2 61-67](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/README.md#L61-L67)), vendored `ethers` with CDN fallback ([S6 246-251](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L246-L251)), and three recorded Pages runs in the snapshot ([S1 lines 82-105]).

## 3) Findings ledger

### KEEPSAKE-01 — chain guard bypass / stale live session
- **Severity / status:** high, confirmed static
- **Evidence:** `ensureChain()` can return `false` for mainnet `143` or return after add-without-recheck ([S6 576-605](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L576-L605)). `connect()` still continues to `getSigner()` and `wire()` (`if (!onChain) note(...); signer = await provider.getSigner(); ... await wire(...)`) ([S6 608-627](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L608-L627)). `fire()` then sends writes without re-checking chain/account ([S6 398-426](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L398-L426)).
- **Impact / correction:** intended refusal is not enforced end-to-end. Static review does **not** prove an actual wrong-chain transaction or loss. Fix by failing closed before wiring, re-reading chain after add/switch, and invalidating live mode on later `chainChanged` / `accountsChanged`.

### KEEPSAKE-02 — spectate board reads via `world`, not the read handle
- **Severity / status:** high, confirmed static
- **Evidence:** reads are designed to use `rw = () => world || roW` ([S6 333-343](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L333-L343)), and `wireRead()` enters `spectate` then calls `refreshKnown()` ([S6 643-709](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L643-L709)). But `refreshKnown()` uses `await world.viewPlayer(a)` and swallows the exception ([S6 499-512](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L499-L512)).
- **Impact / correction:** no-wallet spectate can leave watched players stuck at placeholders. Use the resolved read handle and add a no-wallet negative-controlled test.

### KEEPSAKE-03 — keyboard and label barriers in the core game flow
- **Severity / status:** medium, confirmed static
- **Evidence:** the board instructs users to “Click a cell” ([S6 180-185](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L180-L185)); cells are plain `div`s with no role/tabindex ([S6 314-323](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L314-L323)); interaction is `onclick` only ([S6 560-573](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L560-L573)); setup inputs use placeholders without explicit labels ([S6 225-241](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L225-L241)).
- **Impact / correction:** keyboard-only and AT users cannot complete the inspected board/setup flow. Add explicit input names plus keyboard-operable board semantics or equivalent controls.

### KEEPSAKE-04 — sampled CI evidence is only three recent Pages runs
- **Severity / status:** medium, historical CI
- **Evidence:** the local snapshot lists exactly three successful `pages build and deployment` runs, including the pinned SHA ([S1 lines 82-105]); those runs point to public URLs `33264086847`, `33263900270`, and `33263562184`.
- **Impact / correction:** this is not evidence of full CI, Foundry execution, or wallet-path checks. Keep the claim bounded and add explicit contract/UI gates if release quality depends on them.

### KEEPSAKE-05 — deploy metadata and address resolution can drift
- **Severity / status:** medium, unverified risk
- **Evidence:** the deploy script writes only `world`, `log`, and `block` ([S5 23-41](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/script/Deploy.s.sol#L23-L41)); the client trusts `query string > addresses.json > localStorage > inputs` ([S6 785-805](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L785-L805)).
- **Impact / correction:** I did not establish a live exploit, but I did establish an operational drift surface. Add chain/provenance data and a release parity check before publication.

### KEEPSAKE-06 — rendered wallet/RPC error text crosses an HTML trust boundary
- **Severity / status:** medium, unverified risk
- **Evidence:** `line()` writes arbitrary `html` through `d.innerHTML = html` ([S6 346-349](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L346-L349)). `why(e)` falls back to provider-supplied `e.shortMessage`, `e.reason?.error`, `e.message`, or `String(e)` ([S6 381-389](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L381-L389)). `note()` only replaces `<` before sending the string into `line()` ([S6 358-358](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L358-L358)), and the `verify()` error path writes `why(e)` directly into `verifyOut.innerHTML` ([S6 751-782](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L751-L782)).
- **Impact / correction:** I did not verify exploitability, and no wallet/RPC calls were run here. I did verify a rendered-error trust boundary: untrusted upstream error text is treated as HTML in at least one path and only partially escaped in another. Treat this as an unverified client-side injection risk until error strings are rendered as text, not HTML.

### KEEPSAKE-07 — recovery is forward-only; deploy/dependency assurance is still open
- **Severity / status:** medium, owner decision / unverified risk
- **Evidence:** README treats spare/betrayal as durable facts and the attester pin as permanently ownerless ([S2 9-10](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/README.md#L9-L10), [S2 33-40](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/README.md#L33-L40), [S3 64-76](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/contracts/HonorLog.sol#L64-L76)). README also instructs `export PRIVATE_KEY`, `forge install foundry-rs/forge-std`, and `node script/audit-ui.mjs`, none of which I validated operationally ([S2 61-67](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/README.md#L61-L67), [S2 135-145](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/README.md#L135-L145)).
- **Impact / correction:** republishing the web client cannot revert already-written chain facts. Recovery must be framed as redeploy / republish / retire old URL, not chain rollback. Treat key custody, dependency integrity, and the UI audit gate as open assurance work.

## 4) Five-discipline assessment

- **Correctness:** sampled Solidity invariants look deliberate and are backed by tests; sampled web client has three confirmed defects.
- **Automation:** `test/Keepsake.t.sol` covers core contract semantics ([S7 66-189](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/test/Keepsake.t.sol#L66-L189)), but I saw no sampled automated coverage for the confirmed web defects.
- **DevOps / ops:** deploy order is explicit, but metadata provenance is weak and CI evidence is narrow.
- **OWASP / security:** the primary risk surface is wallet/network/deploy state, not server auth; deployer key handling and dependency integrity remain unverified. Separately, wallet/RPC/provider error text reaches `innerHTML` via `why(e)` and `verifyOut` / `line()` ([S6 346-349](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L346-L349), [S6 381-389](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L381-L389), [S6 751-782](https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L751-L782)); I did not verify exploitability, so I classify it as an unverified rendered-error input risk, not a confirmed exploit.
- **UI / a11y:** mode/status text is present, but the board and setup flow are not source-visible keyboard/AT complete.

## 5) Production blockers and owner questions

- Who is allowed to approve new public addresses or a replacement demo URL?
- Must release CI cover only Pages, or also `forge test` plus mocked wallet/read-path UI checks?
- Should `web/addresses.json` record chain id / provenance, not just addresses and block?
- Is the ethers CDN fallback acceptable, or should missing vendored assets fail release?
- Is recovery formally forward-only, with immutable old chain records left intact?

## 6) Evidence inventory and limitations

Public pinned anchors:

1. **[S2]** <https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/README.md#L1-L151>
2. **[S3]** <https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/contracts/HonorLog.sol#L1-L147>
3. **[S4]** <https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/contracts/World.sol#L1-L282>
4. **[S5]** <https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/script/Deploy.s.sol#L1-L45>
5. **[S6]** <https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/web/index.html#L1-L896>
6. **[S7]** <https://github.com/knarayanareddy/keepsake/blob/1d8c4624e04d40a43951cdbf4098e9ec450802aa/test/Keepsake.t.sol#L1-L204>

Limitations:

- Snapshot-numbered sources materialized only `README.md`; the other inspected files came from **one** separate read-only pinned GitHub GraphQL fetch.
- No install, execution, browser automation, wallet interaction, RPC call, chain read, transaction, deployment, or publication occurred.
- Historical CI statements refer only to the three Pages runs recorded in the local snapshot, not to complete workflow history.
