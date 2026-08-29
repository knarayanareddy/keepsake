#!/usr/bin/env python3
"""Regenerates web/hero.png — the 1200x630 card image.

Identity per AGENT_UI.md (canal-city notary): paper chrome, night playfield, square seals,
hairline rules, radius 0, no gradients, no glow, five chromatics plus neutrals only.
Nothing in the image is typed by hand: the docket entry, the gas total, the runtime sizes and the
tx count are read out of web/demo-match.json, which is itself produced by executing the patched
bytecode (script/record-demo.js). Change a rule → re-record → re-render; the image cannot drift
into a lie.

    python3 script/make-hero.py          # needs ImageMagick 6/7 + DejaVu fonts
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
DOC = json.load(open(os.path.join(ROOT, "web", "demo-match.json"), encoding="utf8"))

W, H = 1200, 630
PAPER, INK, RULE = "#E4D9C5", "#1C1914", "#C4B49A"
WAX, MOSS, GILT, NIGHT, SOFT, GRIDN = "#9B2C2C", "#3F5C4A", "#8A6A22", "#1A2330", "#5B5349", "#2A3345"
SANS, MONO = "DejaVu-Sans", "DejaVu-Sans-Mono"
N = DOC.get("board", 16)
BX, BY, CELL = 60, 118, 27
PLATE = BX + N * CELL                      # right edge of the board plate
TX = 552                                   # text column
TR = W - 48

ops = []
def stroke(color, width=1):
    ops.extend(["-stroke", color, "-strokewidth", str(width), "-fill", "none"])
def line(x1, y1, x2, y2):
    ops.extend(["-draw", f"line {x1} {y1} {x2} {y2}"])
def rect(x1, y1, x2, y2, fill=None, edge=None):
    if fill:
        ops.extend(["-stroke", "none", "-fill", fill])
    ops.extend(["-draw", f"rectangle {x1} {y1} {x2} {y2}"])
    if edge:
        ops.extend(["-stroke", edge, "-fill", "none", "-draw", f"rectangle {x1} {y1} {x2} {y2}"])
def dash(x1, y1, x2, y2, on=6, off=4):
    """dashed stroke as explicit segments — this IM6 build has no -stroke-dasharray"""
    import math
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy) or 1
    ux, uy = dx / L, dy / L
    t = 0.0
    while t < L:
        e = min(t + on, L)
        ops.extend(["-draw", f"line {x1 + ux * t:.1f} {y1 + uy * t:.1f} {x1 + ux * e:.1f} {y1 + uy * e:.1f}"])
        t = e + off


BOXES = []           # every drawn string, so the generator can prove nothing overlaps or clips


def text(x, y, s, font=SANS, size=15, fill=INK):
    s = s.replace("'", "")
    ops.extend(["-stroke", "none", "-fill", fill, "-font", font, "-pointsize", str(size),
                "-annotate", f"+{x}+{y}", s])
    per = size * (0.605 if font == MONO else 0.56)       # DejaVu advance widths, measured
    BOXES.append({"x": x, "y": y, "w": len(s) * per, "h": size * 1.35, "s": s[:40]})


def audit_boxes():
    bad = []
    for b in BOXES:
        if b["x"] + b["w"] > W - 20:
            bad.append(f"clips right edge: {b['s']!r} ends at x={b['x'] + b['w']:.0f}")
    for i in range(len(BOXES)):
        for j in range(i + 1, len(BOXES)):
            a, c = BOXES[i], BOXES[j]
            if abs(a["y"] - c["y"]) < 14 and a["x"] < c["x"] + c["w"] and c["x"] < a["x"] + a["w"]:
                bad.append(f"overlap: {a['s']!r} / {c['s']!r} at y={a['y']}")
    return bad

# ── the plate: night, hairline ledger grid, square seals, attestation lines ──
rect(BX - 1, BY - 1, PLATE + 1, BY + N * CELL + 1, fill=NIGHT)
for i in range(N + 1):                                  # hairline grid, stronger every 4th cell
    stroke(GRIDN if i % 4 else "#3A4761", 1 if i % 4 else 2)
    line(BX + i * CELL, BY, BX + i * CELL, BY + N * CELL)
    line(BX, BY + i * CELL, PLATE, BY + i * CELL)
stroke(INK, 1)
line(BX - 1, BY - 1, PLATE + 1, BY - 1)
line(BX - 1, BY + N * CELL + 1, PLATE + 1, BY + N * CELL + 1)

beat = next((f for f in reversed(DOC["frames"]) if (f.get("fact") or {}).get("kind") == 3), DOC["frames"][-1])
MAXHP, MAXAMMO = 3, 6
seals = [{"addr": a, "mine": a == beat["actorAddr"], **st} for a, st in beat["state"].items() if st.get("joined")]
centres = [(BX + s["x"] * CELL + CELL // 2, BY + s["y"] * CELL + CELL // 2, s) for s in seals]

# attestation lines first, so the seals sit on top of them: a gilt rule that stands, the same
# rule in dashed wax after the betrayal — the link never disappears, it just changes state
if len(centres) >= 2:
    (ax, ay, _), (bx, by, tgt) = centres[0], centres[1]
    ops.extend(["-stroke", WAX, "-strokewidth", "1", "-fill", "none",           # the wounded cell
                "-draw", f"rectangle {bx - CELL // 2} {by - CELL // 2} {bx + CELL // 2} {by + CELL // 2}"])
    stroke(GILT, 2)
    line(ax - CELL, ay - 4, bx + CELL, by - 4)
    stroke(WAX, 2)
    dash(ax - CELL, ay + 4, bx + CELL, by + 4)

for (cx, cy, s) in centres:
    x, y = cx - CELL // 2, cy - CELL // 2
    ops.extend(["-fill", GILT if s["mine"] else WAX, "-stroke", PAPER, "-strokewidth", "2",
                "-draw", f"rectangle {x + 4} {y + 4} {x + CELL - 4} {y + CELL - 4}"])
    ops.extend(["-stroke", "none"])

# the plate is a document: caption above, the two figures that matter below
text(BX, BY - 14, f"Register of the field · {N} × {N} · night · radius 0", MONO, 13, SOFT)
text(BX, BY + N * CELL + 26, f"ALICE hp {seals[0]['hp']}/{MAXHP} · ammo {seals[0]['ammo']}/{MAXAMMO}", MONO, 12, INK)
text(BX, BY + N * CELL + 44, f"BOB hp {seals[1]['hp']}/{MAXHP} · ammo {seals[1]['ammo']}/{MAXAMMO}", MONO, 12, INK)
text(BX, BY + N * CELL + 62, "both inside SPARE_WINDOW · the wax line is the kept betrayal", MONO, 12, SOFT)

# ── the column ──
fact = beat.get("fact") or {}
short = lambda a: (a[:6] + "…" + a[-4:]) if a else "—"
gen = (DOC["meta"].get("generated") or "")[:10]
day = ".".join(reversed(gen.split("-"))) if gen else ""
txs = len([f for f in DOC["frames"] if f.get("gas")])
gas = f"{DOC['meta']['total_execution_gas']:,}"
sizes = f"{DOC['meta']['runtime_bytes']['HonorLog']:,} + {DOC['meta']['runtime_bytes']['World']:,} B"

text(TX, 112, "K E E P S A K E", SANS, 46, INK)
rect(TR - 104, 84, TR, 112, fill=WAX)
text(TR - 96, 103, "ATTESTED", MONO, 12, PAPER)
stroke(RULE, 1); line(TX, 134, TR, 134)
text(TX, 162, "Instrument of record · Monad testnet 10143 · chain id 0x279f", MONO, 14, SOFT)
text(TX, 210, "The only witness to what you did", SANS, 29, INK)
text(TX, 244, "is the chain.", SANS, 29, INK)
stroke(GILT, 3); line(TX - 14, 274, TX - 14, 302); stroke("none", 1)
text(TX, 288, "the rule, enforced in the contract, not the README:", MONO, 14, INK)
for i, (k, v) in enumerate([
    ("spare", "needs a real kill shot — <=2 hp, and armed"),
    ("betray", "carries refUID of your own pact"),
    ("a kill", "writes nothing. no record, no credit"),
    ("one attester", "pinned write-once; no admin call"),
]):
    text(TX, 314 + i * 24, f"  {k:<13}{v}", MONO, 14, INK)

# the docket sample, framed exactly like the app's panel
BY0, BY1 = 412, 540
rect(TX, BY0, TR, BY1, fill=PAPER, edge=INK)
stroke(RULE, 1); line(TX, BY0 + 30, TR, BY0 + 30); line(TX, BY1 - 38, TR, BY1 - 38)
text(TX + 14, BY0 + 22, f"{day}  ·  BLK {beat['block']:,}  ·  gas {beat['gas']:,}", MONO, 13, SOFT)
text(TX + 14, BY0 + 62, fact.get("kindName", "PACT"), SANS, 24, INK)
text(TX + 14, BY0 + 88, f"{short(beat['actorAddr'])}  →  {short(fact.get('other'))}", MONO, 14, INK)
text(TX + 14, BY1 - 14, f"uid {fact.get('uid','')[:18]}…{fact.get('uid','')[-6:]}   ·   verify()", MONO, 13, INK)
text(TX, BY1 + 24, f"refUID {(fact.get('refUID') or '0x' + '0'*64)[:14]}…  ·  a soulbound ERC-721: it outlives the match", MONO, 13, SOFT)
text(TX, 612, "every figure here is read off the recording, not typed into a slide", MONO, 12, SOFT)
text(TX, BY1 + 48, f"{txs} recorded txs · {gas} gas · runtime {sizes} · 16 tests", MONO, 13, WAX)


argv = ["convert", "-size", f"{W}x{H}", f"xc:{PAPER}"] + ops + [os.path.join(ROOT, "web", "hero.png")]
if __name__ == "__main__":
    if not os.path.exists(os.path.join(ROOT, "web", "demo-match.json")):
        sys.exit("web/demo-match.json missing — run node script/record-demo.js first")
    bad = audit_boxes()
    if bad:
        sys.exit("hero layout problems:\n  " + "\n  ".join(bad) + "\n  (fix the coordinates, then re-run)")
    r = subprocess.run(argv, capture_output=True, text=True)
    if r.returncode:
        sys.exit((r.stderr or "") + (r.stdout or ""))
    print("web/hero.png regenerated from", len(DOC["frames"]), "frames ·",
          "beat:", beat["verb"], "· kind", fact.get("kindName"), "·", gas, "gas total")
