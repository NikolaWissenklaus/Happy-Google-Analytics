// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Test harness for the JS UDFs: extracts the body between r""" and """ and runs it
// like BigQuery would (function with the declared params).
const fs = require("fs");
const path = require("path");
const root = process.argv[2];

function loadUdf(rel, params) {
  const text = fs.readFileSync(path.join(root, rel), "utf8");
  const start = text.indexOf('r"""') + 4;
  const end = text.indexOf('"""', start);
  const body = text.substring(start, end);
  return new Function(...params, body);
}

let failures = 0;
function check(name, cond, extra = "") {
  console.log((cond ? "PASS " : "FAIL ") + name + (extra ? "  " + extra : ""));
  if (!cond) failures++;
}

// ---------------------------------------------------------------- random helpers
let seed = 42;
function rand() { seed = (seed * 1664525 + 1013904223) % 4294967296; return (seed + 0.5) / 4294967296; }
function randNormal() { return Math.sqrt(-2 * Math.log(rand())) * Math.cos(2 * Math.PI * rand()); }
// Marsaglia-Tsang gamma(shape, rate)
function randGamma(shape, rate) {
  if (shape < 1) return randGamma(shape + 1, rate) * Math.pow(rand(), 1 / shape);
  const d = shape - 1 / 3, c = 1 / Math.sqrt(9 * d);
  for (;;) {
    let x, v;
    do { x = randNormal(); v = 1 + c * x; } while (v <= 0);
    v = v * v * v;
    const u = rand();
    if (u < 1 - 0.0331 * x * x * x * x) return d * v / rate;
    if (Math.log(u) < 0.5 * x * x + d * (1 - v + Math.log(v))) return d * v / rate;
  }
}
function randBeta(a, b) { const x = randGamma(a, 1), y = randGamma(b, 1); return x / (x + y); }
function randExp(rate) { return -Math.log(rand()) / rate; }

// ---------------------------------------------------------------- privacy
const cpf = loadUdf("privacy/is_valid_cpf.sqlx", ["value"]);
check("cpf valid formatted", cpf("529.982.247-25") === true);
check("cpf valid raw", cpf("52998224725") === true);
check("cpf wrong digit", cpf("529.982.247-24") === false);
check("cpf repeated", cpf("111.111.111-11") === false);
check("cpf null", cpf(null) === null);

const cnpj = loadUdf("privacy/is_valid_cnpj.sqlx", ["value"]);
check("cnpj numeric valid", cnpj("11.222.333/0001-81") === true);
check("cnpj alphanumeric RFB example", cnpj("12.ABC.345/01DE-35") === true);
check("cnpj wrong", cnpj("11.222.333/0001-82") === false);
check("cnpj short", cnpj("1122233300018") === false);

const luhn = loadUdf("privacy/luhn_check.sqlx", ["value"]);
check("luhn visa test", luhn("4111 1111 1111 1111") === true);
check("luhn wrong", luhn("4111 1111 1111 1112") === false);
check("luhn mastercard test", luhn("5555555555554444") === true);

const decode = loadUdf("urls_text/url_decode.sqlx", ["value"]);
check("url_decode", decode("t%C3%AAnis+azul") === "tênis azul");
check("url_decode invalid keeps input", decode("100%") === "100%");

// ---------------------------------------------------------------- bayes
const probB = loadUdf("stats/prob_b_beats_a.sqlx", ["alpha_a", "beta_a", "alpha_b", "beta_b"]);
let wins = 0; const sims = 200000;
for (let i = 0; i < sims; i++) if (randBeta(121, 881) > randBeta(101, 901)) wins++;
const exact = probB(101, 901, 121, 881);
check("prob_b_beats_a exact vs monte carlo", Math.abs(exact - wins / sims) < 0.01, `exact=${exact.toFixed(4)} mc=${(wins / sims).toFixed(4)}`);
const approx = probB(101.5, 901, 121.5, 881);
check("prob_b_beats_a normal approx close", Math.abs(approx - exact) < 0.02, `approx=${approx.toFixed(4)}`);
check("prob_b_beats_a symmetric", Math.abs(probB(50, 50, 50, 50) - 0.5) < 0.02, probB(50, 50, 50, 50).toFixed(4));

// ---------------------------------------------------------------- BG/NBD
const fitBg = loadUdf("models/fit_bg_nbd.sqlx", ["data", "penalizer"]);
const predictBg = loadUdf("models/bg_nbd_predict.sqlx", ["x", "t_x", "t_cal", "horizon", "r", "alpha", "a", "b"]);
const truth = { r: 0.24, alpha: 4.41, a: 0.79, b: 2.43 };
const customers = [];
for (let c = 0; c < 6000; c++) {
  const lambda = randGamma(truth.r, truth.alpha);
  const p = randBeta(truth.a, truth.b);
  const T = 39 + rand() * 39;
  let t = 0, x = 0, tx = 0, alive = true;
  // first purchase at 0 (start of the customer), repeat purchases after
  for (;;) {
    t += randExp(lambda);
    if (t > T) break;
    x++; tx = t;
    if (rand() < p) { alive = false; break; }
  }
  // future purchases in the next 13 weeks (for checking predictions)
  let future = 0;
  if (alive) {
    let t2 = T;
    // memoryless: next purchase after T
    for (;;) {
      t2 += randExp(lambda);
      if (t2 > T + 13) break;
      future++;
      if (rand() < p) break;
    }
  }
  customers.push({ x, t_x: tx, t_cal: T, n: 1, future });
}
const t0 = Date.now();
const fit = fitBg(customers.map(c => ({ x: c.x, t_x: c.t_x, t_cal: c.t_cal, n: 1 })), 0);
const ms = Date.now() - t0;
console.log("     bg/nbd fit:", JSON.stringify(fit), `(${ms} ms)`);
check("bg/nbd converged", fit && fit.converged === true);
check("bg/nbd r close", Math.abs(fit.r - truth.r) / truth.r < 0.25, fit.r.toFixed(3));
check("bg/nbd alpha close", Math.abs(fit.alpha - truth.alpha) / truth.alpha < 0.35, fit.alpha.toFixed(3));
check("bg/nbd a close", Math.abs(fit.a - truth.a) / truth.a < 0.4, fit.a.toFixed(3));
check("bg/nbd b close", Math.abs(fit.b - truth.b) / truth.b < 0.5, fit.b.toFixed(3));
let predSum = 0, actualSum = 0, aliveOk = true;
customers.forEach(c => {
  const p = predictBg(c.x, c.t_x, c.t_cal, 13, fit.r, fit.alpha, fit.a, fit.b);
  if (!(p.p_alive >= 0 && p.p_alive <= 1)) aliveOk = false;
  predSum += p.expected_purchases;
  actualSum += c.future;
});
check("bg/nbd p_alive in [0,1]", aliveOk);
check("bg/nbd expected purchases vs simulated future", Math.abs(predSum - actualSum) / actualSum < 0.12, `pred=${predSum.toFixed(1)} actual=${actualSum}`);
check("bg/nbd x=0 alive=1", predictBg(0, 0, 50, 13, fit.r, fit.alpha, fit.a, fit.b).p_alive === 1);

// grouped input must give the same answer as one row per customer
const grouped = {};
customers.forEach(c => {
  const k = [c.x, Math.round(c.t_x), Math.round(c.t_cal)].join("|");
  grouped[k] = grouped[k] || { x: c.x, t_x: Math.round(c.t_x), t_cal: Math.round(c.t_cal), n: 0 };
  grouped[k].n++;
});
const fitGrouped = fitBg(Object.values(grouped), 0.001);
check("bg/nbd grouped input works", fitGrouped && Math.abs(fitGrouped.r - fit.r) / fit.r < 0.3, `rows=${Object.keys(grouped).length} r=${fitGrouped.r.toFixed(3)}`);

// ---------------------------------------------------------------- Gamma-Gamma
const fitGg = loadUdf("models/fit_gamma_gamma.sqlx", ["data", "penalizer"]);
const gg = { p: 6.25, q: 3.74, v: 15.44 };
const spend = [];
for (let c = 0; c < 5000; c++) {
  const x = 1 + Math.floor(rand() * 8);
  const nu = randGamma(gg.q, gg.v);
  let s = 0;
  for (let k = 0; k < x; k++) s += randGamma(gg.p, nu);
  spend.push({ x, m: s / x, n: 1 });
}
const ggFit = fitGg(spend, 0);
console.log("     gamma-gamma fit:", JSON.stringify(ggFit));
check("gamma-gamma converged", ggFit && ggFit.converged);
const popMean = ggFit.p * ggFit.v / (ggFit.q - 1), truePopMean = gg.p * gg.v / (gg.q - 1);
check("gamma-gamma population mean spend", Math.abs(popMean - truePopMean) / truePopMean < 0.1, `fit=${popMean.toFixed(2)} true=${truePopMean.toFixed(2)}`);

// ---------------------------------------------------------------- Markov
const markov = loadUdf("models/markov_removal_effects.sqlx", ["paths"]);
const mk = markov([
  { path: ["A", "B"], conversions: 1, non_conversions: 0 },
  { path: ["A"], conversions: 0, non_conversions: 1 },
  { path: ["B"], conversions: 1, non_conversions: 0 }
]);
console.log("     markov:", JSON.stringify(mk));
// by hand: start->A 2/3, start->B 1/3, A->B 1/2, A->null 1/2, B->conv 1
// P(conv) = 2/3*1/2 + 1/3 = 2/3. remove A: 1/3 -> effect 0.5. remove B: 0 -> effect 1
const effA = mk.find(m => m.channel === "A").removal_effect;
const effB = mk.find(m => m.channel === "B").removal_effect;
check("markov base probability", Math.abs(mk[0].base_conversion_probability - 2 / 3) < 1e-9);
check("markov removal A = 0.5", Math.abs(effA - 0.5) < 1e-9);
check("markov removal B = 1", Math.abs(effB - 1) < 1e-9);
check("markov shares sum 1", Math.abs(mk.reduce((s, m) => s + m.share, 0) - 1) < 1e-9);

// ---------------------------------------------------------------- Shapley
const shapley = loadUdf("models/shapley_values.sqlx", ["coalitions", "max_channels"]);
const sv = shapley([
  { channels: ["A"], conversions: 10 },
  { channels: ["B"], conversions: 5 },
  { channels: ["A", "B"], conversions: 20 }
], 14);
console.log("     shapley:", JSON.stringify(sv));
check("shapley A = 20", Math.abs(sv.find(s => s.channel === "A").shapley_value - 20) < 1e-9);
check("shapley B = 15", Math.abs(sv.find(s => s.channel === "B").shapley_value - 15) < 1e-9);
const many = [];
for (let i = 0; i < 300; i++) {
  const chs = [];
  for (let k = 0; k < 18; k++) if (rand() < 0.15) chs.push("ch" + k);
  if (chs.length) many.push({ channels: chs, conversions: 1 + Math.floor(rand() * 5) });
}
const t1 = Date.now();
const svMany = shapley(many, 14);
const total = many.reduce((s, c) => s + c.conversions, 0);
check("shapley 18 channels capped + efficiency", Math.abs(svMany.reduce((s, x) => s + x.shapley_value, 0) - total) < 1e-6, `players=${svMany.length} ${Date.now() - t1} ms`);

// ---------------------------------------------------------------- CUSUM
const cusum = loadUdf("models/cusum.sqlx", ["standardized_values", "k", "h"]);
const series = [];
for (let i = 0; i < 30; i++) series.push(0);
for (let i = 0; i < 30; i++) series.push(1);
const cs = cusum(series, 0.5, 5);
const firstAlarm = cs.findIndex(c => c.alarm_high);
check("cusum alarms after the shift", firstAlarm >= 39 && firstAlarm <= 41, `first alarm at ${firstAlarm}`);
check("cusum no alarm before", cs.slice(0, 30).every(c => !c.alarm_high && !c.alarm_low));

console.log(failures === 0 ? "\nALL GOOD" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
