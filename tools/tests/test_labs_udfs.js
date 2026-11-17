// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Tests of the JS UDFs of the labs models (pagerank, absorbing_markov_values), same harness
// idea of test_js_udfs.js: the body between r""" and """ runs like BigQuery would run it.
//
// usage (from tools/): node tests/test_labs_udfs.js ../definitions/01_udfs
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
const close = (a, b, tol = 1e-6) => Math.abs(a - b) < tol;

// ---------------------------------------------------------------- pagerank
const pagerank = loadUdf("models/pagerank.sqlx", ["edges", "damping", "iterations"]);

// a ring: everybody is equal
const ring = pagerank([
  { src: "a", dst: "b", weight: 1 }, { src: "b", dst: "c", weight: 1 }, { src: "c", dst: "a", weight: 1 }
], 0.85, 50);
check("pagerank ring is uniform", ring.every(r => close(r.pagerank, 1 / 3)), JSON.stringify(ring.map(r => r.pagerank.toFixed(4))));
check("pagerank sums 1", close(ring.reduce((s, r) => s + r.pagerank, 0), 1));

// a star: everybody points to the hub, the hub points back to one page
const star = pagerank([
  { src: "p1", dst: "hub", weight: 5 }, { src: "p2", dst: "hub", weight: 5 }, { src: "p3", dst: "hub", weight: 5 },
  { src: "hub", dst: "p1", weight: 1 }
], 0.85, 60);
check("pagerank hub wins", star[0].node === "hub", star[0].node);
check("pagerank star sums 1", close(star.reduce((s, r) => s + r.pagerank, 0), 1));
check("pagerank in/out weights", star.find(r => r.node === "hub").in_weight === 15 && star.find(r => r.node === "hub").out_weight === 1);

// dangling node (no way out) must not leak score
const dangling = pagerank([{ src: "a", dst: "b", weight: 1 }], 0.85, 80);
check("pagerank dangling keeps the total", close(dangling.reduce((s, r) => s + r.pagerank, 0), 1));
check("pagerank dangling target ranks first", dangling[0].node === "b");

// by hand, 2 nodes a -> b (b dangling): rb = 0.15/2 + 0.85*(ra + rb/2), ra = 0.15/2 + 0.85*rb/2
// => ra = 0.350877, rb = 0.649123
check("pagerank by hand", close(dangling.find(r => r.node === "a").pagerank, 0.350877, 1e-5), dangling.find(r => r.node === "a").pagerank.toFixed(6));

check("pagerank empty", pagerank([], 0.85, 10).length === 0);
check("pagerank null input", pagerank(null, null, null).length === 0);
check("pagerank ignores self loops and bad rows", pagerank([{ src: "a", dst: "a", weight: 9 }, { src: null, dst: "b", weight: 1 }], 0.85, 10).length === 0);

// weight matters: a sends 9 to b and 1 to c
const weighted = pagerank([
  { src: "a", dst: "b", weight: 9 }, { src: "a", dst: "c", weight: 1 }, { src: "b", dst: "a", weight: 1 }, { src: "c", dst: "a", weight: 1 }
], 0.85, 80);
check("pagerank respects weights", weighted.find(r => r.node === "b").pagerank > 3 * weighted.find(r => r.node === "c").pagerank);

const big = [];
let seed = 7;
const rand = () => { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; };
for (let i = 0; i < 60000; i++) big.push({ src: "p" + Math.floor(rand() * 1500), dst: "p" + Math.floor(rand() * 1500), weight: 1 + Math.floor(rand() * 20) });
const t0 = Date.now();
const bigRank = pagerank(big, 0.85, 40);
check("pagerank 1500 pages / 60k edges", close(bigRank.reduce((s, r) => s + r.pagerank, 0), 1, 1e-6), `${bigRank.length} nodes, ${Date.now() - t0} ms`);

// ---------------------------------------------------------------- absorbing markov
const markov = loadUdf("models/absorbing_markov_values.sqlx", ["transitions", "success_state", "failure_state", "iterations"]);
const value = (rows, state) => rows.find(r => r.state === state);

// start -> A (1). A -> buy 0.3, A -> exit 0.7
const simple = markov([
  { src: "start", dst: "A", weight: 10 },
  { src: "A", dst: "buy", weight: 3 }, { src: "A", dst: "exit", weight: 7 }
], "buy", "exit", 100);
check("markov simple value of A", close(value(simple, "A").success_probability, 0.3));
check("markov simple value of start", close(value(simple, "start").success_probability, 0.3));
check("markov absorbing states", value(simple, "buy").success_probability === 1 && value(simple, "exit").success_probability === 0);
check("markov steps", close(value(simple, "A").expected_steps, 1) && close(value(simple, "start").expected_steps, 2));

// a loop: A -> B 0.5, A -> exit 0.5, B -> A 0.5, B -> buy 0.5
// vA = 0.5 vB, vB = 0.5 vA + 0.5 => vA = 1/3, vB = 2/3
// nA = 1 + 0.5 nB, nB = 1 + 0.5 nA => nA = nB = 2
const loop = markov([
  { src: "A", dst: "B", weight: 1 }, { src: "A", dst: "exit", weight: 1 },
  { src: "B", dst: "A", weight: 1 }, { src: "B", dst: "buy", weight: 1 }
], "buy", "exit", 500);
check("markov loop value of A = 1/3", close(value(loop, "A").success_probability, 1 / 3, 1e-8), value(loop, "A").success_probability.toFixed(8));
check("markov loop value of B = 2/3", close(value(loop, "B").success_probability, 2 / 3, 1e-8));
check("markov loop steps = 2", close(value(loop, "A").expected_steps, 2, 1e-6) && close(value(loop, "B").expected_steps, 2, 1e-6));

// transitions leaving an absorbing state are ignored, a state with no exit is a failure
const weird = markov([
  { src: "A", dst: "buy", weight: 1 }, { src: "A", dst: "limbo", weight: 1 },
  { src: "buy", dst: "A", weight: 50 }
], "buy", "exit", 100);
check("markov ignores exits of absorbing states", close(value(weird, "A").success_probability, 0.5));
check("markov dead end is a failure", value(weird, "limbo").success_probability === 0);
check("markov empty", markov([], "buy", "exit", 10).length === 0);
check("markov probabilities in [0,1]", loop.concat(simple, weird).every(r => r.success_probability >= 0 && r.success_probability <= 1));

// ---------------------------------------------------------------- mSPRT (the SQL of the UDF, mirrored)
// keeps the formula honest: no difference -> p = 1, big difference with data -> tiny p,
// and under the null the always valid p value crosses 5% in less than 5% of the experiments
function msprt(convA, nA, convB, nB, tau2) {
  const pa = convA / nA, pb = convB / nB;
  const v = pa * (1 - pa) / nA + pb * (1 - pb) / nB;
  if (!(v > 0)) return 1;
  const diff = pb - pa;
  return Math.min(1, 1 / (Math.sqrt(v / (v + tau2)) * Math.exp(Math.min(700, tau2 * diff * diff / (2 * v * (v + tau2))))));
}
const sql = fs.readFileSync(path.join(root, "stats/msprt_p_value.sqlx"), "utf8");
check("msprt sql has the formula of the test", sql.includes("SQRT(v / (v + t2))") && sql.includes("t2 * diff * diff / (2 * v * (v + t2))"));
check("msprt no difference = 1", msprt(100, 1000, 100, 1000, 0.0001) === 1);
check("msprt clear winner", msprt(300, 10000, 420, 10000, 0.0001) < 0.001, msprt(300, 10000, 420, 10000, 0.0001).toExponential(2));
let falseAlarmsSequential = 0, falseAlarmsNaive = 0;
const experiments = 400;
for (let x = 0; x < experiments; x++) {
  let ca = 0, cb = 0, n = 0, minP = 1, naiveHit = false;
  for (let day = 0; day < 30; day++) {
    for (let u = 0; u < 300; u++) { if (rand() < 0.05) ca++; if (rand() < 0.05) cb++; }
    n += 300;
    minP = Math.min(minP, msprt(ca, n, cb, n, 0.0001));
    const pa = ca / n, pb = cb / n, pool = (ca + cb) / (2 * n);
    const z = (pb - pa) / Math.sqrt(2 * pool * (1 - pool) / n);
    if (Math.abs(z) > 1.96) naiveHit = true;
  }
  if (minP < 0.05) falseAlarmsSequential++;
  if (naiveHit) falseAlarmsNaive++;
}
check("msprt false positives under 5% with daily peeking", falseAlarmsSequential / experiments <= 0.05, `sequential=${(100 * falseAlarmsSequential / experiments).toFixed(1)}%  naive z-test peeking=${(100 * falseAlarmsNaive / experiments).toFixed(1)}%`);
check("naive peeking really inflates (the reason this exists)", falseAlarmsNaive / experiments > 0.1);

console.log(failures === 0 ? "\nALL GOOD" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
