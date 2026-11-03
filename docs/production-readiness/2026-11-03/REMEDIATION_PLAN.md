# KEEPSAKE remediation plan

Nothing below was executed in this session. All commands, tests, and rehearsals are **future work**, not completion evidence.

## 1) Phased roadmap with entry / exit criteria

### Phase 0 — Baseline and ownership
- **Entry:** review baseline is SHA `1d8c4624e04d40a43951cdbf4098e9ec450802aa`.
- **Exit:** five discipline owners, deploy approver, and source-of-truth release artifacts are named.

### Phase 1 — Confirmed client defects
- **Entry:** KEEPSAKE-01 to KEEPSAKE-03 remain open.
- **Exit:** wallet guard fails closed, spectate reads through the read path, and keyboard/label barriers are fixed.

### Phase 2 — Security and release boundaries
- **Entry:** metadata provenance, deploy key handling, dependency assurance, and rollback language are incomplete.
- **Exit:** release parity is explicit and recovery language no longer implies chain rollback.

### Phase 3 — Automation
- **Entry:** contract tests exist; sampled CI evidence only proves three recent Pages runs.
- **Exit:** negative controls catch the confirmed defects and contract regressions.

### Phase 4 — Deployment / recovery rehearsal
- **Entry:** deploy order is documented in code but operational proof is missing.
- **Exit:** an owner-approved **isolated** future rehearsal has been defined and, before acceptance can close, must produce observed evidence for redeployment, metadata/address migration, preserved immutable old records, and recovery messaging. Documentation alone is not Phase 4 completion, and the isolated drill is distinct from any later public deployment.

### Phase 5 — Independent acceptance
- **Entry:** implementation owners say their tasks are done.
- **Exit:** non-implementing reviewers verify outputs and negative controls separately from owner approval.

## 2) Role-owned tasks

### KEEPSAKE-T1 — Fail closed on chain/account state
- **Owner:** Security owner
- **Linked finding:** KEEPSAKE-01
- **Observed paths:** `web/index.html` `ensureChain()`, `connect()`, `fire()`, `wire()`
- **Prerequisites:** supported wallets, allowed chain ids, and disconnect behavior are agreed.
- **Action steps:**
  1. Stop `connect()` before `getSigner()` / `wire()` unless the wallet is confirmed on an allowed chain after switch/add.
  2. Re-check chain/account state immediately before every write.
  3. Invalidate live mode on later `chainChanged` and `accountsChanged` events.
- **Expected deliverable:** a live mode that cannot survive refused, stale, or changed wallet state.
- **Verification:**
  1. Mock chain `143` and failed switch; confirm live mode is unreachable.
  2. Mock add-without-switch; confirm success is not reported until chain is re-read.
  3. Mock later chain/account change; confirm writes are blocked before another contract call.
- **DoD:**
  - [ ] No signer-backed live mode after failed/declined switch.
  - [ ] Every write re-validates chain/account.
  - [ ] Later wallet changes visibly clear or disable live state.

### KEEPSAKE-T2 — Repair spectate reads
- **Owner:** Correctness owner
- **Linked finding:** KEEPSAKE-02
- **Observed paths:** `rw()`, `wireRead()`, `refreshKnown()`
- **Prerequisites:** intended no-wallet spectate behavior is agreed.
- **Action steps:**
  1. Read player state through the resolved read handle, not `world`.
  2. Surface real read failures instead of silently keeping placeholders.
  3. Add a no-wallet mocked read-path regression test.
- **Expected deliverable:** spectate mode that shows actual player state without a signer.
- **Verification:**
  1. Mock a watched player in read-only mode and confirm coordinates/state render.
  2. Reintroduce the bug deliberately and confirm the test fails.
  3. Confirm live mode still reads correctly after the same refactor.
- **DoD:**
  - [ ] No-wallet spectate renders real player data.
  - [ ] Read failures are visible, not silently healthy.
  - [ ] Regression test catches the old `world.viewPlayer` bug.

### KEEPSAKE-T3 — Make the board and setup flow keyboard / AT complete
- **Owner:** UI / accessibility owner
- **Linked finding:** KEEPSAKE-03
- **Observed paths:** board markup, cell creation, click handlers, UID/watch/world/log/block inputs
- **Prerequisites:** accessible board interaction model and minimum label bar are chosen.
- **Action steps:**
  1. Add explicit labels or equivalent accessible names for all setup and verify inputs.
  2. Add keyboard-operable movement/target controls or equivalent accessible board semantics.
  3. Keep preview / spectate / live status understandable without pointer-only interaction.
- **Expected deliverable:** core game flow usable without mouse-only clicks.
- **Verification:**
  1. Planned keyboard-only acceptance reaches connect, setup, target, move, and verify.
  2. Planned AT checks confirm meaningful names for the inputs and board controls.
  3. Negative control fails if focusability or labels are removed.
- **DoD:**
  - [ ] Inputs have explicit accessible names.
  - [ ] Board actions are available without pointer-only clicks.
  - [ ] Mode/target state stays intelligible to non-visual users.

### KEEPSAKE-T4 — Add release parity for chain/address provenance
- **Owner:** DevOps / operations owner
- **Linked findings:** KEEPSAKE-04, KEEPSAKE-05
- **Observed paths:** `script/Deploy.s.sol`, `web/addresses.json`, `resolveAddrs()`
- **Prerequisites:** one release manifest and one deploy approver are named.
- **Action steps:**
  1. Define the authoritative release fields: chain id, `world`, `log`, deploy block, and public URL.
  2. Add a parity check that blocks publication on field drift.
  3. Decide whether query/local overrides remain demo-only or release-acceptable.
- **Expected deliverable:** a machine-checkable release truth map.
- **Verification:**
  1. Deliberately mismatch one field and confirm the gate blocks release.
  2. Confirm docs, deploy output, and client all refer to the same authoritative fields.
  3. Confirm operator override behavior is documented, not assumed.
- **DoD:**
  - [ ] Chain id is part of release metadata.
  - [ ] Address / chain drift is detectable before publication.
  - [ ] Public metadata changes require explicit approval.

### KEEPSAKE-T5 — Turn findings into negative-controlled automation
- **Owner:** Automation / testing owner
- **Linked findings:** KEEPSAKE-01 to KEEPSAKE-04
- **Observed paths:** `test/Keepsake.t.sol`, README-documented `script/audit-ui.mjs`, CI snapshot metadata
- **Prerequisites:** existing trusted scripts are identified; uninspected scripts are not over-claimed as gates.
- **Action steps:**
  1. Keep the existing Foundry regressions and add planned UI regressions for wallet guard, spectate path, and keyboard flow.
  2. Require at least one deliberate-break negative control per confirmed defect.
  3. Report Pages, contract, and UI status separately.
- **Expected deliverable:** automation that distinguishes static-site success from broader product health.
- **Verification:**
  1. Break a contract invariant and confirm contract tests fail.
  2. Reintroduce a confirmed web defect and confirm the planned UI test fails.
  3. Confirm a green Pages job does not hide a red contract/UI job.
- **DoD:**
  - [ ] Contract invariants remain automated.
  - [ ] Each confirmed client defect has a failing negative control.
  - [ ] CI status language is scoped honestly.

### KEEPSAKE-T6 — Define forward-only recovery and independent acceptance
- **Owner:** DevOps owner for recovery; independent verifier for acceptance
- **Linked finding / requirement:** KEEPSAKE-07 and author-contract independent acceptance
- **Observed scope:** release docs, deploy path, all tasks above
- **Prerequisites:** recovery approver, **explicit deployment authorizer**, rehearsal bar, and independent reviewers are named.
- **Action steps:**
  1. State plainly that republishing the web client does **not** revert already-written chain facts or an old pinned attester.
  2. Define forward-only recovery options: isolated redeploy rehearsal, metadata/address migration, replacement URL/manifest publication, preserved references to immutable old records, and deprecation messaging for the old entry point.
  3. Require separate written authorization for any future rehearsal deploy and for any future public deployment or address publication; approval of the recovery model alone is not deployment approval.
  4. Require non-implementing reviewers to verify outputs, negative controls, and any future rehearsal evidence before release sign-off.
- **Expected deliverable:** a recovery policy, explicit deployment authorization rule, and an isolated-rehearsal plan that do not confuse plans, docs, observed drills, and actual public deployment.
- **Verification:**
  1. Walk the runbook and confirm irreversible steps are explicitly marked, including immutable old records that stay public after replacement.
  2. For the future isolated rehearsal, require observed evidence of redeployment, metadata/address migration, preserved old-record handling, and recovery communication; simulated drills stay labelled as simulated until that evidence exists.
  3. Confirm the independent verifier must review that rehearsal evidence separately from documentation and separately from any later public deployment approval.
- **DoD:**
  - [ ] Recovery language does not imply chain rollback.
  - [ ] Forward migration steps and immutable-old-record handling are explicit and owner-approved.
  - [ ] Rehearsal deploy authority and public deploy authority are explicit and separate.
  - [ ] Acceptance is independent and requires rehearsal evidence, not documentation alone.

## 3) Dependency map

| Task | Depends on | Blocks |
|---|---|---|
| T1 | Phase 0 decisions | T5, T6 |
| T2 | none | T5, T6 |
| T3 | Phase 0 a11y bar | T5, T6 |
| T4 | Phase 0 release authority | T6 |
| T5 | T1-T3 | T6 |
| T6 | T4 + T5 evidence | release confidence |

## 4) Production acceptance checklist

- [ ] Live mode fails closed on refused, stale, or changed wallet state.
- [ ] Spectate mode renders real player state with no wallet.
- [ ] Keyboard/label acceptance is complete.
- [ ] Release metadata includes chain provenance and blocks drift.
- [ ] Pages, contract, and UI checks report separately.
- [ ] Recovery docs do not claim on-chain rollback.
- [ ] Future isolated recovery rehearsal evidence exists and is reviewed independently before acceptance closes.
- [ ] Final acceptance is performed by non-implementing reviewers.

## 5) Owner approvals required

- Supported-wallet and fail-closed policy
- Authoritative release manifest fields
- Whether query/local overrides are demo-only or release-acceptable
- Who may authorize an isolated rehearsal deploy
- Who may approve new public addresses / URLs or any public deployment
- Forward-only recovery model for immutable old chain records

## 6) Release / recovery policy

- Do not treat Pages success alone as product health.
- Do not treat a web republish as reversal of on-chain state.
- If deployment metadata is wrong, recover forward: rehearse in isolation if needed, redeploy if authorized, publish replacement metadata, preserve references to immutable old records, and clearly retire the old entry point.
- Keep simulated future drills, owner approval, and any eventual real deploy rehearsal as separate evidence classes.
