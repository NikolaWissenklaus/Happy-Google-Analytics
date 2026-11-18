// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Tests of the JS UDFs of the extended attribution (attribution_extended tag).
// node tests/test_attribution_udfs.js ../definitions/01_udfs
const fs = require("fs");
const path = require("path");
const root = process.argv[2] || path.join(__dirname, "..", "..", "definitions", "01_udfs");

function loadUdf(rel, params) {
  const text = fs.readFileSync(path.join(root, rel), "utf8");
  const start = text.indexOf('r"""') + 4;
  const end = text.indexOf('"""', start);
  return new Function(...params, text.substring(start, end));
}

let failures = 0;
function check(name, cond, extra = "") {
  console.log((cond ? "PASS " : "FAIL ") + name + (extra ? "  " + extra : ""));
  if (!cond) failures++;
}

let seed = 7;
function rand() { seed = (seed * 1664525 + 1013904223) % 4294967296; return (seed + 0.5) / 4294967296; }
function randExp(rate) { return -Math.log(rand()) / rate; }

// ---------------------------------------------------------------- markov of order k
const markov1 = loadUdf("models/markov_removal_effects.sqlx", ["paths"]);
const markovK = loadUdf("models/markov_removal_effects_k_order.sqlx", ["paths", "k"]);

const samplePaths = [
  { path: ["A"], conversions: 10, non_conversions: 10 },
  { path: ["A", "B"], conversions: 30, non_conversions: 10 },
  { path: ["B"], conversions: 5, non_conversions: 35 },
  { path: ["C", "A", "B"], conversions: 8, non_conversions: 4 },
  { path: ["B", "C"], conversions: 1, non_conversions: 9 }
];
const first = markov1(samplePaths);
const k1 = markovK(samplePaths, 1);
const byChannel = arr => Object.fromEntries(arr.map(r => [r.channel, r]));
const f = byChannel(first), g = byChannel(k1);
check("k=1 matches the first order UDF (base probability)", Math.abs(first[0].base_conversion_probability - k1[0].base_conversion_probability) < 1e-9);
check("k=1 matches the first order UDF (removal effects)",
  ["A", "B", "C"].every(c => Math.abs(f[c].removal_effect - g[c].removal_effect) < 1e-9));

// order matters: A then B converts, B then A never does. A first order chain cannot see it
const orderPaths = [
  { path: ["A", "B"], conversions: 50, non_conversions: 0 },
  { path: ["B", "A"], conversions: 0, non_conversions: 50 }
];
const o1 = markovK(orderPaths, 1), o2 = markovK(orderPaths, 2);
check("order 2 has more states than order 1", o2[0].states > o1[0].states, `states k1=${o1[0].states} k2=${o2[0].states}`);
check("order 2 base probability = observed 0.5", Math.abs(o2[0].base_conversion_probability - 0.5) < 1e-6, `p=${o2[0].base_conversion_probability}`);
// A > C converts, B > C never does: B never helps. Order 1 mixes the two C states and gives B
// credit (removal effect 0.5), order 2 sees that B is useless (removal effect 0)
const memoryPaths = [
  { path: ["A", "C"], conversions: 50, non_conversions: 0 },
  { path: ["B", "C"], conversions: 0, non_conversions: 50 }
];
const m1 = byChannel(markovK(memoryPaths, 1)), m2 = byChannel(markovK(memoryPaths, 2));
check("order 1 wrongly credits B", Math.abs(m1.B.removal_effect - 0.5) < 1e-6, `effect=${m1.B.removal_effect}`);
check("order 2 gives B nothing", m2.B.removal_effect < 1e-6, `effect=${m2.B.removal_effect}`);
check("order 2 keeps A and C essential", m2.A.removal_effect > 0.999 && m2.C.removal_effect > 0.999);
const shareSum = o2.reduce((a, r) => a + r.share, 0);
check("order 2 shares sum 1", Math.abs(shareSum - 1) < 1e-9);
check("order 3 runs on long paths", markovK([{ path: ["A", "B", "C", "D", "A"], conversions: 3, non_conversions: 2 }], 3).length === 4);
check("empty input", markovK([], 2).length === 0);

// ---------------------------------------------------------------- additive hazard
const hazard = loadUdf("models/additive_hazard_attribution.sqlx", ["journeys", "half_lives", "iterations"]);

// simulate: baseline 0.003 / day, one touch of A causes 0.30 conversions, of B 0.05, half life 2 days
const trueB0 = 0.003, trueBeta = { A: 0.30, B: 0.05 }, trueHalf = 2, horizon = 30;
const w = Math.LN2 / trueHalf;
function lambdaAt(t, touches) {
  let l = trueB0;
  touches.forEach(x => { if (x.days <= t) l += trueBeta[x.channel] * w * Math.exp(-w * (t - x.days)); });
  return l;
}
const journeys = [];
for (let u = 0; u < 6000; u++) {
  const n = 1 + Math.floor(rand() * 4);
  const touches = [];
  for (let i = 0; i < n; i++) touches.push({ channel: rand() < 0.5 ? "A" : "B", days: rand() * horizon });
  touches.sort((a, b) => a.days - b.days);
  const lambdaMax = trueB0 + touches.reduce((a, x) => a + trueBeta[x.channel] * w, 0);
  let t = 0, converted = false;
  for (;;) {
    t += randExp(lambdaMax);
    if (t >= horizon) break;
    if (rand() < lambdaAt(t, touches) / lambdaMax) { converted = true; break; }
  }
  const end = converted ? t : horizon;
  journeys.push({ converted, end_days: end, weight: 1, value: converted ? 100 : 0, touches: touches.filter(x => x.days <= end) });
}
const t0 = Date.now();
const fitted = hazard(journeys, [0.5, 1, 2, 4, 8, 16], 150);
const ms = Date.now() - t0;
const h = byChannel(fitted);
console.log("     hazard:", JSON.stringify(fitted.map(r => ({ c: r.channel, beta: +r.beta.toFixed(4), share: +r.share.toFixed(3), hl: r.half_life_days }))), ms + " ms");
check("hazard picks the true half life", h.A.half_life_days === trueHalf, `hl=${h.A.half_life_days}`);
check("hazard recovers beta A", Math.abs(h.A.beta - trueBeta.A) / trueBeta.A < 0.2, `beta=${h.A.beta.toFixed(4)}`);
check("hazard recovers beta B", Math.abs(h.B.beta - trueBeta.B) < 0.03, `beta=${h.B.beta.toFixed(4)}`);
check("hazard recovers the baseline", Math.abs(h["(baseline)"].beta - trueB0) / trueB0 < 0.35, `b0=${h["(baseline)"].beta.toFixed(5)}`);
const conversions = journeys.filter(j => j.converted).length;
const attributed = fitted.reduce((a, r) => a + r.attributed_conversions, 0);
check("hazard credits sum the conversions", Math.abs(attributed - conversions) < 1e-6 * conversions + 1e-6, `${attributed.toFixed(2)} vs ${conversions}`);
check("hazard shares sum 1", Math.abs(fitted.reduce((a, r) => a + r.share, 0) - 1) < 1e-9);
check("hazard empty input", hazard([], [1], 10).length === 0);

console.log(failures === 0 ? "\nALL GOOD" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
