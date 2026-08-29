#!/usr/bin/env node
/**
 * script/audit-ui.mjs — checks web/index.html against AGENT_UI.md, mechanically.
 *
 * The brief asks for a rendered screenshot to prove a restyle. This sandbox (and most CI) has no browser, so the
 * rules that CAN be read off the stylesheet are asserted here instead: the token values, the ban-list (radius,
 * gradients, glow, pills of colour, pure white/black/gray, off-scale type, banned display faces, bounce), and
 * WCAG contrast computed from each rule's own colour/background pair rather than from a hopeful mock-up.
 *
 *   node script/audit-ui.mjs          # exit 1 and a list of violations on any breach
 *
 * It is a floor, not a ceiling: it cannot tell you whether the board *looks* like a notary's register.
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(ROOT, "web", "index.html"), "utf8");
const css = html.match(/<style>([\s\S]*?)<\/style>/)[1];
const fail = [], pass = [];
const t = (c, cond, msg) => (cond ? pass : fail).push(c + " — " + msg);

// tokens: every var(--x) must be declared, and declared exactly as the brief specifies
const declared = new Set([...css.matchAll(/(--[a-z-]+):\s*([^;]+);/g)].map((m) => m[1]));
const used = new Set([...css.matchAll(/var\((--[a-z-]+)/g)].map((m) => m[1]));
t("tokens", [...used].every((v) => declared.has(v)), `undeclared: ${[...used].filter((v) => !declared.has(v)).join(",") || "none"}`);
for (const [k, v] of Object.entries({ "--paper": "#E4D9C5", "--ink": "#1C1914", "--rule": "#C4B49A", "--wax": "#9B2C2C", "--moss": "#3F5C4A", "--gilt": "#8A6A22", "--night": "#1A2330", "--stamp": "#6E1E1E" })) {
  const re = new RegExp(`${k}:\\s*${v}`, "i");
  t(`token ${k}`, re.test(css), "value must match AGENT_UI §4 exactly");
}

// banned surfaces
t("radius", !/border-radius:\s*(?!0\b|0px|50%)/.test(css.replace(/border-radius: 0;/g, "")), "only radius 0 (50% never used: seals are squares)");
t("seals are square", !/border-radius:\s*50%/.test(css), "no round dots anywhere");
t("gradients", !/gradient\(/.test(css), "no linear/radial/conic gradients");
const shadows = [...css.matchAll(/box-shadow:\s*([^;]+);/g)].map((m) => m[1]);
const glowing = shadows.filter((sh) => sh.split(/,(?![^(]*\))/).some((part) => {
  const nums = (part.match(/-?\d*\.?\d+px/g) || []).map(parseFloat);
  const blur = part.includes("inset") ? (nums[3] ?? nums[2] ?? 0) : (nums[2] ?? 0);
  return blur > 0;
}));
t("no glow", glowing.length === 0, `blur-free hairline rings only (found ${glowing.length} blurred)`);
t("no pure black/white/gray", !/#fff\b|#ffffff|#000\b|#000000|#888\b/i.test(css), "banned by §6");
for (const f of ["Inter", "Roboto", "Open Sans", "Chakra Petch", "Arial"]) {
  const usedAsDisplay = new RegExp(`--(register|instrument):[^;]*${f.replace(/ /g, "")}`, "i").test(css);
  t(`font ${f}`, !usedAsDisplay, "not in a role stack");
}
t("purple/lilac", !/#(6|7|8|9)[0-9a-f]d{2}|lilac|violet|indigo/i.test(css), "no Monad marketing purple");
// tracking: wordmark <= 0.12em
const tracks = [...css.matchAll(/letter-spacing:\s*([0-9.]+)em/g)].map((m) => Number(m[1]));
t("tracking", tracks.length && Math.max(...tracks) <= 0.12, `max used = ${Math.max(...tracks)}em (wordmark cap 0.12em)`);
// scale: only 12/15/19/24/30 px
const sizes = [...new Set([...css.matchAll(/font-size:\s*(\d+)px/g)].map((m) => Number(m[1])))].sort((a, b) => a - b);
t("type scale", sizes.every((s) => [12, 15, 19, 24, 30].includes(s)), `sizes in use: ${sizes.join(", ")}`);
t("body >= 15px", /body\s*{[^}]*font-size:\s*15px/.test(css.replace(/\s+/g, " ")) || /font-size: 15px/.test(css), "15px base");
t("tabular nums", /font-variant-numeric:\s*tabular-nums/.test(css), "figures align in the docket");
t("no bounce", !/cubic-bezier\(|elastic|bounce|@keyframes/.test(css), "no keyframes; motion is transition-only");
const durs = [...css.matchAll(/(\d+)ms/g)].map((m) => Number(m[1])).filter((d) => d > 0);
t("motion 120–180ms", durs.every((d) => d >= 120 && d <= 180), `durations: ${[...new Set(durs)].join(", ")}ms`);
t("reduced motion", /prefers-reduced-motion/.test(css), "honoured");
t("focus ring", /outline:\s*2px solid var\(--ink\)/.test(css), "2px ink offset focus");

// WCAG contrast on the pairs §5 asks for
const hex = (h) => { const [r, g, b] = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const ratio = (a, b) => { const [x, y] = [hex(a), hex(b)].sort((m, n) => n - m); return (x + 0.05) / (y + 0.05); };
const P = "#E4D9C5", I = "#1C1914", N = "#1A2330", W = "#9B2C2C", M = "#3F5C4A", G = "#8A6A22", S = "#5B5349";
const TOK = { paper: P, ink: I, rule: "#C4B49A", wax: W, moss: M, gilt: G, night: N, stamp: "#6E1E1E" };
const lum = (h) => { const c = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((x) => (x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4)); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; };
const over = (fg, a, bg) => { const h = (i) => Math.round(parseInt(fg.slice(i, i + 2), 16) * a + parseInt(bg.slice(i, i + 2), 16) * (1 - a)).toString(16).padStart(2, "0"); return "#" + h(1) + h(3) + h(5); };
const blocks = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)]
  .map(([, sel, body]) => ({ sel: sel.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/\s+/g, " ").trim().slice(-34), body }));
const checked = [];
for (const { sel, body } of blocks) {
  const cm = body.match(/(?:^|[;\s])color:\s*var\(--([a-z]+)\)/), bgm = body.match(/background(?:-color)?:\s*var\(--([a-z]+)\)/);
  const rg = body.match(/background:\s*rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)/);
  let bg = null;
  if (bgm && TOK[bgm[1]]) bg = TOK[bgm[1]];
  else if (rg) bg = over("#" + [1, 2, 3].map((i) => Number(rg[i]).toString(16).padStart(2, "0")).join(""), Number(rg[4]), P);
  if (!cm || !bg || !TOK[cm[1]]) continue;
  const fg = TOK[cm[1]], r = ratio(fg, bg);
  checked.push(`${sel}: ${fg}/${bg} ${r.toFixed(2)}`);
  t(`AA ${sel.slice(-30)}`, r >= 4.5, `${r.toFixed(2)}:1 for text on ${bg}`);
}
// the pairs the brief names explicitly, whatever the cascade does
for (const [name, fg, bg, need] of [["ink on paper", I, P, 4.5], ["paper on night", P, N, 4.5], ["paper on wax", P, W, 4.5], ["paper on moss", P, M, 4.5], ["soft ink on paper", S, P, 4.5], ["wax on paper", W, P, 4.5], ["moss on paper", M, P, 4.5], ["gilt rule on paper (non-text, 3:1)", G, P, 3]]) {
  const r = ratio(fg, bg);
  t(`AA ${name}`, r >= need, `${r.toFixed(2)}:1 (needs ${need}:1)`);
}
t("rules with color+background pair", checked.length > 0, `${checked.length} styled text rules checked against their own background`);
console.log(fail.length ? "\n✗ " + fail.length + " css violations:\n  " + fail.join("\n  ") : "\n✓ css audit clean");
console.log(`  ${pass.length} checks passed.`);
console.log(fail.length ? "" : "");
process.exitCode = fail.length ? 1 : 0;
