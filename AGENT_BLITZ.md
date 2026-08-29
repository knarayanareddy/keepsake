# AGENT BRIEF — Blitz platform, submission, and remaining product gaps

Give this to the builder **with** `HANDOVER.md` and `AGENT_UI.md`. This file is about **shipping on [blitz.devnads.com](https://blitz.devnads.com/)**, not about restyling.

If this file conflicts with DESIGN.md on visuals, UI kit wins. If it conflicts with HANDOVER on product verbs, HANDOVER wins. **This file wins on submit/live/vote.**

---

## 0. What the platform is

Monad Blitz is **not only an IRL pitch**. Official OS: **https://blitz.devnads.com/**

Amsterdam event page: `https://blitz.devnads.com/events/monad-blitz-amsterdam`  
29 Aug 2026, 09:00–20:00 GMT+2, ~65 approved, status **Live**.

Site loop:

1. **Sign up** → register for Amsterdam → get approved.  
2. **Claim testnet MON** *on that site* (event-gated). Do not assume a random faucet is what they track.  
3. **Build**, then **submit: live demo URL + GitHub**. Present in the room.  
4. **Peer vote 1–5.** Top-voted take prizes. Cards on the homepage *are* the competition.

Luma freeze ~18:00 / submit ~18:30 / pitches ~18:45 — treat **the Devnads submit button** as the real freeze. Submit before you line up to talk.

---

## 1. What winning cards look like (so you don’t write an essay)

From live Blitz projects (Belgrade, Abuja, etc.):

| Do | Don’t |
|----|--------|
| First sentence = what it **does** | Architecture / “trustless bridge” essay |
| **https Live** that opens on a phone | `http://localhost:3000` (seen on platform — voters cannot use it) |
| GitHub with a 60-second README | Empty repo |
| One Monad hook (felt speed, or a real number) | “Built on Monad” with no reason |
| One still image | No image / purple mesh slop |
| Optional Demo tweet | — |

Closest cousin in the gallery: Civic Pulse (on-chain reputation). KEEPSAKE must **not** read as civic incident reporting. Differentiator: **you cannot self-attest; spare/betrayal is the only way a fact exists.**

Do **not** pivot to CLOB, insurance, GPU marketplace, or agent portfolio — those already occupy the homepage.

---

## 2. Card copy (use / trim, don’t reinvent)

**Title:** KEEPSAKE  

**Short (~400 chars):**  
KEEPSAKE is a 16×16 on-chain arena. Pact, spare, or shoot — each choice mints an attestation. You cannot certify yourself; the World contract is the only attester. Close the laptop: `verify(uid)` still says who was spared.

**Monad hook (one line, honest):**  
Sub-second blocks so a spare is a **fact in the same breath as the move** — not a 12-second Ethereum ritual.

**Pitch closer (script; optional `tokenURI` later):**  
*If my laptop dies, the chain still remembers who was spared.*  
Do **not** spend the afternoon implementing on-chain SVG unless P0–P1 below are done. Poetry now; `tokenURI` is P2.

---

## 3. Builder sequence (P0 → P2)

### P0 — no vote without these

1. Human: **sign in** on blitz.devnads.com → Amsterdam → **claim MON**.  
2. **Deploy** World + HonorLog on the **same network the event faucet uses**. `setWorld` must run (see `script/Deploy.s.sol`). Put addresses in README.  
3. **Bake addresses into the UI** (constants or `?world=&log=`). Deploy box stays, but voters must not need it.  
4. **Public GitHub** (this repo).  
5. **Hosted Live URL** (Vercel, GitHub Pages, or equivalent **HTTPS**). `python -m http.server` is **only** for the on-stage laptop. `web/index.html` loads ethers from esm.sh — needs network.  
6. **Submit** on Devnads: title, blurb, repo, live, screenshot when you have one.  
7. Never set Live to localhost.

### P1 — pitch + strangers clicking Live

8. **Two-player visibility** (`AGENT_UI.md` §0): `Spawned` / `Moved` / `Shot` → `seen`. Fallback: “watch address” input.  
   Voters open Live **alone**. An empty grid = 1/5. Consider a spectator path or two documented demo wallets.  
9. **Add Monad network** in one click (chain id + RPC from official docs). Wrong-network is how peer votes die.  
10. Public Monad RPC in the frontend — no localhost RPC.  
11. **README “try in 60s”:** connect → spawn → optional paste opponent → stand adjacent → Pact / Spare.  
12. Rehearse 90s IRL (HANDOVER §6).

### P2 — if ahead

13. Paper/wax restyle (`AGENT_UI.md`) + one **still** for the Devnads card (board + docket, not a generic dashboard).  
14. Optional dual-chain timing (Monad vs Sepolia) — only if you have a real number. Don’t fake it.  
15. Optional `tokenURI` SVG stamp — **after** P0–P1. Not “30 minutes.”

---

## 4. README skeleton for voters (replace TODOs)

```markdown
# KEEPSAKE
The World is the only attester.

Live: https://TODO
World: 0xTODO
HonorLog: 0xTODO
Network: Monad (TODO chain id)  RPC: TODO

## 60 seconds
1. Wallet on Monad, some MON.
2. Open Live, Connect, Spawn.
3. Second wallet: same, Spawn. If you don’t see them, paste their address in Watch.
4. Stand on adjacent cells. Pact → Spare (or Shoot).
5. UID appears. Paste into verify().

You cannot attest yourself. Spare and betrayal are facts that outlive the match.
```

---

## 5. Still frozen (do not reopen)

- No MUD, official EAS, prize pots, Eliza, x402, Three.js, extra verbs.  
- Pact remains one-way; attestations remain **inline**.  
- No money in the contract. Gas only.  
- Don’t `/impeccable init` over DESIGN.md.

---

## 6. Done when (platform)

- [ ] Amsterdam event: registered + MON claimed on Devnads  
- [ ] Contracts deployed; `setWorld` verified on explorer  
- [ ] Live HTTPS URL works on a phone **without the builder present**  
- [ ] GitHub + Devnads submission with blurb above  
- [ ] Two players (or watch-address) visible  
- [ ] `verify(uid)` works from the Live UI  

Room pitch is extra credit on top of a card people can actually open.
