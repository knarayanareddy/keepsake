# AGENT BRIEF — KEEPSAKE UI / UX

Give this file to the builder agent **as law** for anything visual. Do not restyle from taste, from Monad marketing, or from `index.html`’s current CSS.

**You (builder) own the UI pass.** The previous session did **not** restyle the board. Do not wait for another human/agent to “finish design” first. Sequence is below.

---

## 0. Do this in order (do not skip 1)

1. **Fix two-player visibility** (functional; demo-blocking).  
   Today `seen` only holds `me` + whoever you already targeted. Player B never appears on A’s board.  
   Subscribe to `Spawned`, `Moved`, `Shot` on `World` from deploy block (or `0`). On `Spawned`, `seen.set(player, await viewPlayer(player))`. Same for moves. Keep polling as backup.  
   **Do not change element IDs or the ethers method names.**  
2. **Then** restyle `web/index.html` to this kit (CSS + light markup). Same JS IDs (`connect`, `spawn`, `board`, `pact`, `spare`, `shoot`, `seal`, `log`, `uidIn`, `verify`, `worldIn`, `logIn`, `saveAddr`, `meAddr`, `vitals`, `tgt`, `verifyOut`).  
3. Hide Deploy behind `<details>` once addresses are in `localStorage`.  
4. HonorLog as a **docket of stamps**, not a terminal dump. `verify()` as a definition list; JSON in `<details>` if needed.  
5. **Stop.** No landing page, no SVG keepsake, no Three.js, no token, no extra frameworks.

If hour-pressure: ship (1) even if (2) is half-done. A working two-player ugly board beats a pretty one-player museum.

---

## 1. Product (so you don’t skin the wrong thing)

KEEPSAKE is a **notarial instrument that is also a 16×16 match**. Pact / spare / shoot mint attestations; the World is the only attester. Judges should think “archive / Amsterdam notary,” not “on-chain game HUD” or “DeFi terminal.”

Copy voice: short, legal, specific. Never seamless / unlock / empower / trustless magic. Errors: “Not adjacent.” “No ammo.” Tagline once: *The world is the only attester.*

---

## 2. Why the current UI is not the brand

`web/index.html` is a **mood sketch**: `#07080c`, Georgia/Palatino, `0.28em` gold tracking, ghost-gold buttons, blood/ok, round dots.

That is a known LLM default (“dark luxury crypto” + “editorial serif kicker”). Impeccable-class detectors flag it. **Throw out that skin. Keep the structure and IDs.**

---

## 3. Identity

**Canal-city notary wired to a live match.** Damp bone paper, lampblack, sealing-wax, hairline ledger grid. Bureaucratic, a little cruel.

- Product chrome = **paper**.  
- Playfield only = **night** (canal water).  
- Pieces = **square seals**, not circles.  
- Radius = **0**. Buttons = **rubber stamps**, not pills.

Anti-references: Linear, Rainbow, OpenSea, glass wallets, Monad purple marketing, Inter+gradient SaaS, TypeUI “Impeccable” amber/Chakra Petch (different product — not us).

---

## 4. Tokens (use exactly)

```css
:root {
  --paper: #E4D9C5;
  --ink:   #1C1914;
  --rule:  #C4B49A;
  --wax:   #9B2C2C;   /* shoot, betrayal, destructive */
  --moss:  #3F5C4A;   /* spare, ok */
  --gilt:  #8A6A22;   /* pact, small emphasis — never page fill */
  --night: #1A2330;   /* board ground only */
  --stamp: #6E1E1E;   /* pressed */
}
```

Five chromatic + neutrals. **No gradients.** Accent budget: one extra chromatic besides the pieces.

Type — **two families, three roles**:

| Role | Face | Fallback | Use |
|------|------|----------|-----|
| Register | Newsreader or Source Serif 4 | Georgia | Wordmark, kind names (PACT) |
| Instrument | IBM Plex Sans | Helvetica Neue | UI, stamps |
| Docket | IBM Plex Mono | ui-monospace | addresses, UIDs, hp/ammo |

Wordmark tracking ≤ `0.12em`. Scale 12 / 15 / 19 / 24 / 30. Body ≥ 15px. Tabular nums. Fonts: Google or IBM CDN if network allows; if offline, keep **roles** (Georgia / Helvetica / Menlo) but still paper+wax, still radius 0, still no gold-outline ghosts.

---

## 5. Components

**Layout:** left = 1:1 board (max ~72vh). Right = docket: hairlines, no filled cards, sections divided by rules.

**Stamps (buttons):** 1px ink border, 8×12 padding, Plex ~12–13.  
- Primary (Spawn after connect): fill `--ink`, type `--paper`.  
- Pact: fill `--gilt`, type `--paper`.  
- Spare: fill `--moss`, type `--paper`.  
- Shoot: fill `--wax`, type `--paper`.  
- Connect / secondary: paper fill, ink border.  
One primary per region.

**Inputs:** ink hairline, mono for hex, no rounded search.

**Board:** `--night`, `--rule` 1px, 16×16. Me = gilt square; them = wax square; dead = 30% ink. Pact = gilt hairline between cells; betrayal = wax line that remains.

**HonorLog entry:**

```
29.08.2026  ·  BLK 18422910
SPARE
0xA2…c1  →  0x91…ee
uid  0x8f3c…     [verify]
```

**Empty:** “No target. Stand adjacent.” “No match sealed.”

**Focus:** 2px ink offset. Motion: 120–180ms `ease` on stamp/line only. No bounce, no pulse, no stagger-in.

**a11y:** AA for ink-on-paper and paper-on-night. Don’t use color alone (line + label). Don’t put gray text on wax.

---

## 6. Banned (Impeccable / UI UX Pro Max / anti-slop)

Inter, Roboto, Open Sans, Arial as display. Purple–cyan/blue mesh. Glass, glow, neon. 12–16px radius cards. Cards in cards. Pure `#000` `#fff` `#888`. Gray on colored fills. Bounce/elastic. Pulsing dots. Rounded-square icons over headings. Side-tab accents. Centered hero + bento. Palatino+gold+huge tracking on dark (**current file**). Chakra Petch + amber. Monad lilac. “Unlock your potential.”

---

## 7. Skills — how to use, how not to

- **Impeccable** (pbakaus / impeccable.style): detectors + `/polish` `/distill` `/critique`. **Do not `/impeccable init`** — it would overwrite this identity. Optional: run detectors *after* restyle.  
- **UI/UX Pro Max:** do not re-roll “crypto → purple.” Domain is *attestation + arena*, not a CEX.  
- Anthropic frontend-design / anti-slop: same bans as §6.

This document **is** the DESIGN.md + PRODUCT.md for the UI pass. Also see `DESIGN.md` / `PRODUCT.md` in repo if you need longer rationale. If they conflict with this file on tokens or sequence, **this file wins.**

---

## 8. Out of scope (HANDOVER still applies)

No MUD, official EAS, prize pots, SVG tokenURI, Eliza, x402, Three.js, new verbs. Contracts stay as-is unless a UI bug requires a view/event that already exists (`Spawned`, `Moved`, `Shot`, `Attested`).

Pitch line (unchanged): *A future DAO can require spared ≥ 1 without me building that DAO.*

---

## 9. Done when

- Two wallets spawn and **both dots/seals visible** on each board without manually pasting the other’s address (address watch as fallback is OK).  
- Paper chrome, night board, stamp verbs, docket log, `verify()` readable at 2m on a projector.  
- A stranger would not guess “v0 / GPT dark crypto.” They might guess “notary.”
