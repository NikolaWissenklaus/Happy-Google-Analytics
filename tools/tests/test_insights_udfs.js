// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Tests of the UDFs of the insights models (tag: insights). Same harness of test_js_udfs.js: the
// body between r""" and """ runs like BigQuery would run it, and every model is checked against
// data simulated with KNOWN parameters (it must give them back). The SQL UDFs are mirrored in JS
// and the test checks that the SQL still has the same formula.
//
// usage (from tools/): node tests/test_insights_udfs.js ../definitions/01_udfs
const fs = require("fs");
const path = require("path");
const root = process.argv[2] || path.join(__dirname, "..", "..", "definitions", "01_udfs");

function loadUdf(rel, params) {
  const text = fs.readFileSync(path.join(root, rel), "utf8");
  const start = text.indexOf('r"""') + 4;
  const end = text.indexOf('"""', start);
  return new Function(...params, text.substring(start, end));
}
const readSql = rel => fs.readFileSync(path.join(root, rel), "utf8");

let failures = 0;
function check(name, cond, extra = "") {
  console.log((cond ? "PASS " : "FAIL ") + name + (extra ? "  " + extra : ""));
  if (!cond) failures++;
}
const close = (a, b, tol) => Math.abs(a - b) <= tol;

let seed = 2026;
function rand() { seed = (seed * 1664525 + 1013904223) % 4294967296; return (seed + 0.5) / 4294967296; }
function randNormal() { return Math.sqrt(-2 * Math.log(rand())) * Math.cos(2 * Math.PI * rand()); }
function randExp(rate) { return -Math.log(rand()) / rate; }

// ---------------------------------------------------------------- PELT change points
const pelt = loadUdf("models/pelt_changepoints.sqlx", ["series", "penalty_multiplier", "min_segment_length"]);
const regimes = [];
for (let i = 0; i < 60; i++) regimes.push(10 + randNormal());
for (let i = 0; i < 80; i++) regimes.push(14 + randNormal());
for (let i = 0; i < 60; i++) regimes.push(9 + randNormal());
const seg = pelt(regimes, 3, 14);
check("pelt finds 3 regimes", seg.length === 3, JSON.stringify(seg.map(s => [s.start_index, s.end_index, +s.mean.toFixed(2)])));
check("pelt boundaries near the truth", seg.length === 3 && Math.abs(seg[1].start_index - 60) <= 3 && Math.abs(seg[2].start_index - 140) <= 3);
check("pelt means near the truth", seg.length === 3 && close(seg[0].mean, 10, 0.4) && close(seg[1].mean, 14, 0.4) && close(seg[2].mean, 9, 0.4));
check("pelt segments cover the series", seg[0].start_index === 0 && seg[seg.length - 1].end_index === regimes.length - 1 && seg.reduce((a, s) => a + s.points, 0) === regimes.length);
check("pelt noise sigma close to 1", close(seg[0].noise_sigma, 1, 0.2), seg[0].noise_sigma.toFixed(3));
const flat = [];
for (let i = 0; i < 200; i++) flat.push(5 + randNormal());
check("pelt flat series = 1 regime", pelt(flat, 3, 14).length === 1);
const spike = flat.slice();
spike[100] = 40;
check("pelt one outlier day is not a regime", pelt(spike, 3, 14).length === 1);
check("pelt short series = 1 regime", pelt([1, 2, 3, 4, 5], 3, 14).length === 1);
check("pelt empty", pelt([], 3, 14).length === 0);
check("pelt constant series", pelt(new Array(50).fill(7), 3, 7).length === 1);

// ---------------------------------------------------------------- Holt-Winters
const hw = loadUdf("models/holt_winters_forecast.sqlx", ["series", "season_length", "horizon", "holdout"]);
const weekly = [1.0, 1.1, 1.05, 1.0, 0.95, 0.7, 0.8];
const truth = t => (1000 + 2 * t) * weekly[t % 7];
const history = [];
for (let t = 0; t < 364; t++) history.push(truth(t) + 15 * randNormal());
const t0 = Date.now();
const fc = hw(history, 7, 28, 28);
const ms = Date.now() - t0;
check("holt winters returns the fit", fc && fc.points.length === 364 + 28, `${ms} ms, alpha=${fc.alpha} beta=${fc.beta} gamma=${fc.gamma} phi=${fc.phi}`);
check("holt winters backtest error small", fc.holdout_mape < 0.05, `mape=${(fc.holdout_mape * 100).toFixed(2)}%`);
const future = fc.points.filter(p => p.is_forecast);
const futureMape = future.reduce((a, p, k) => a + Math.abs(p.fitted - truth(364 + k)) / truth(364 + k), 0) / future.length;
check("holt winters forecast close to the truth", futureMape < 0.05, `mape=${(futureMape * 100).toFixed(2)}%`);
const inside = future.filter((p, k) => truth(364 + k) >= p.low_95 && truth(364 + k) <= p.high_95).length;
check("holt winters 95% interval covers the truth", inside >= 24, `${inside}/28`);
check("holt winters intervals widen", future[27].high_95 - future[27].low_95 > future[0].high_95 - future[0].low_95);
check("holt winters too short = null", hw([1, 2, 3, 4, 5, 6, 7, 8], 7, 7, 0) === null);

// ---------------------------------------------------------------- gaussian mixture
const gmm = loadUdf("stats/gaussian_mixture_1d.sqlx", ["sample_values", "iterations"]);
const mix = [];
for (let i = 0; i < 4000; i++) mix.push(rand() < 0.6 ? 1 + 0.3 * randNormal() : 4 + 0.5 * randNormal());
const g = gmm(mix, 300);
check("gmm recovers the means", close(g.mean_low, 1, 0.05) && close(g.mean_high, 4, 0.05), `${g.mean_low.toFixed(3)} / ${g.mean_high.toFixed(3)}`);
check("gmm recovers the weights", close(g.weight_low, 0.6, 0.03), g.weight_low.toFixed(3));
check("gmm recovers the sds", close(g.sd_low, 0.3, 0.03) && close(g.sd_high, 0.5, 0.04), `${g.sd_low.toFixed(3)} / ${g.sd_high.toFixed(3)}`);
check("gmm says two groups", g.bic_two_components < g.bic_one_component - 10 && g.separation > 2, `D=${g.separation.toFixed(2)}`);
check("gmm threshold between the means", g.threshold > 1 && g.threshold < 4, g.threshold.toFixed(3));
const uni = [];
for (let i = 0; i < 4000; i++) uni.push(2 + randNormal());
const gu = gmm(uni, 300);
check("gmm unimodal sample is not two groups", !(gu.bic_two_components < gu.bic_one_component - 10 && gu.separation > 2), `bic1=${gu.bic_one_component.toFixed(1)} bic2=${gu.bic_two_components.toFixed(1)} D=${gu.separation.toFixed(2)}`);
check("gmm small sample = null", gmm([1, 2, 3], 10) === null);

// ---------------------------------------------------------------- Cox proportional hazards
const cox = loadUdf("models/fit_cox_ph.sqlx", ["subjects", "covariate_names", "l2", "iterations"]);
const trueB = [0.5, -0.4, 0];
const subjects = [];
for (let i = 0; i < 6000; i++) {
  const x1 = rand() < 0.4 ? 1 : 0;
  const x2 = randNormal() * 0.8 + 3;
  const x3 = rand() < 0.5 ? 1 : 0;
  const rate = 0.02 * Math.exp(trueB[0] * x1 + trueB[1] * (x2 - 3) + trueB[2] * x3);
  const time = randExp(rate);
  const censor = 20 + rand() * 120;
  // durations in whole days, like the SQL sends them (ties happen)
  subjects.push({ duration: Math.ceil(Math.min(time, censor)), event: time <= censor, covariates: [x1, x2, x3] });
}
const t1 = Date.now();
const fitted = cox(subjects, ["x1", "x2", "x3"], 0.0001, 30);
const coxMs = Date.now() - t1;
const byName = Object.fromEntries(fitted.map(r => [r.covariate, r]));
check("cox converges", fitted[0].converged, `${coxMs} ms, events=${fitted[0].events}`);
check("cox recovers beta of a binary covariate", close(byName.x1.coef, 0.5, 0.08), byName.x1.coef.toFixed(3));
check("cox recovers beta of a continuous covariate", close(byName.x2.coef, -0.4, 0.06), byName.x2.coef.toFixed(3));
check("cox null covariate is not significant", byName.x3.p_value > 0.01 && close(byName.x3.coef, 0, 0.1), `p=${byName.x3.p_value.toFixed(3)}`);
check("cox real effects are significant", byName.x1.p_value < 1e-6 && byName.x2.p_value < 1e-6);
check("cox interval contains the truth", byName.x1.hr_low < Math.exp(0.5) && byName.x1.hr_high > Math.exp(0.5));
check("cox concordance above chance", fitted[0].concordance > 0.55 && fitted[0].concordance < 0.8, fitted[0].concordance.toFixed(3));
const constant = cox(subjects.map(s => ({ duration: s.duration, event: s.event, covariates: [s.covariates[0], 1] })), ["x1", "always_one"], 0.0001, 30);
check("cox constant covariate gets NULL", constant.find(r => r.covariate === "always_one").coef === null && constant.find(r => r.covariate === "x1").coef !== null);
check("cox empty input", cox([], ["x"], 0.01, 10).length === 0);

// ---------------------------------------------------------------- synthetic control
const synth = loadUdf("models/synthetic_control_weights.sqlx", ["treated", "donors", "iterations"]);
const T = 90;
const donorSeries = [0, 1, 2, 3].map(k => {
  const s = [];
  for (let t = 0; t < T; t++) s.push(1 + 0.2 * Math.sin((t + 7 * k) / (3 + k)) + 0.05 * randNormal());
  return s;
});
const treatedSeries = [];
for (let t = 0; t < T; t++) treatedSeries.push(0.6 * donorSeries[0][t] + 0.4 * donorSeries[2][t] + 0.002 * randNormal());
const weights = synth(treatedSeries, donorSeries.map((s, k) => ({ donor: "d" + k, series: s })), 5000);
const wOf = Object.fromEntries(weights.map(r => [r.donor, r.weight]));
check("synthetic control recovers the weights", close(wOf.d0, 0.6, 0.03) && close(wOf.d2, 0.4, 0.03) && wOf.d1 < 0.03 && wOf.d3 < 0.03, JSON.stringify(weights.map(r => [r.donor, +r.weight.toFixed(3)])));
check("synthetic control weights on the simplex", close(weights.reduce((a, r) => a + r.weight, 0), 1, 1e-6) && weights.every(r => r.weight >= 0));
check("synthetic control good pre fit", weights[0].pre_rmspe < 0.01, weights[0].pre_rmspe.toFixed(5));
check("synthetic control skips donors with another length", synth([1, 2, 3, 4], [{ donor: "a", series: [1, 2, 3] }], 100).length === 0);

// ---------------------------------------------------------------- Bass diffusion
const bass = loadUdf("models/fit_bass_diffusion.sqlx", ["adoptions", "horizon"]);
const F = (t, p, q) => (1 - Math.exp(-(p + q) * t)) / (1 + (q / p) * Math.exp(-(p + q) * t));
const bp = 0.01, bq = 0.4, bm = 10000;
const adopters = [];
for (let t = 1; t <= 26; t++) adopters.push(bm * (F(t, bp, bq) - F(t - 1, bp, bq)) * (1 + 0.03 * randNormal()));
const b = bass(adopters, 8);
check("bass recovers p", close(b.p, bp, 0.0025), b.p.toFixed(4));
check("bass recovers q", close(b.q, bq, 0.04), b.q.toFixed(3));
check("bass recovers m", close(b.m, bm, 600), b.m.toFixed(0));
check("bass peak period", close(b.peak_period, Math.log(bq / bp) / (bp + bq), 1), b.peak_period.toFixed(2));
check("bass fit is good", b.r2 > 0.95 && b.forecast.length === 8, b.r2.toFixed(3));
const early = adopters.slice(0, 5);
const be = bass(early, 4);
check("bass before the peak flags m as a floor or keeps m >= adopters", be.m >= early.reduce((a, v) => a + v, 0) - 1e-6);
check("bass empty = null", bass([0, 0, 0], 4) === null);

// ---------------------------------------------------------------- Louvain
const louvain = loadUdf("models/louvain_communities.sqlx", ["edges", "max_levels"]);
function clique(prefix, k, w) {
  const out = [];
  for (let i = 0; i < k; i++) for (let j = i + 1; j < k; j++) out.push({ src: prefix + i, dst: prefix + j, weight: w });
  return out;
}
const two = clique("a", 5, 1).concat(clique("b", 5, 1)).concat([{ src: "a0", dst: "b0", weight: 1 }]);
const parts = louvain(two, 10);
const commOf = Object.fromEntries(parts.map(r => [r.node, r.community]));
const aSame = ["a1", "a2", "a3", "a4"].every(n => commOf[n] === commOf.a0);
const bSame = ["b1", "b2", "b3", "b4"].every(n => commOf[n] === commOf.b0);
check("louvain splits two cliques", aSame && bSame && commOf.a0 !== commOf.b0, JSON.stringify([...new Set(parts.map(r => r.community))]));
// by hand: m = 21, each clique has 10 internal edges and degree sum 21 -> Q = 2 (10/21 - (21/42)^2) = 0.452381
check("louvain modularity by hand", close(parts[0].modularity, 2 * (10 / 21 - 0.25), 1e-9), parts[0].modularity.toFixed(6));
const ring = [];
["p", "q", "r", "s"].forEach((p, k, all) => {
  clique(p, 4, 1).forEach(e => ring.push(e));
  ring.push({ src: p + "0", dst: all[(k + 1) % 4] + "1", weight: 1 });
});
const ringParts = louvain(ring, 10);
check("louvain ring of 4 cliques = 4 communities", new Set(ringParts.map(r => r.community)).size === 4);
check("louvain community size", ringParts.every(r => r.community_size === 4));
check("louvain empty", louvain([], 10).length === 0);
check("louvain ignores self loops and bad weights", louvain([{ src: "x", dst: "x", weight: 3 }, { src: "x", dst: "y", weight: -1 }], 10).length === 0);
const big = [];
for (let i = 0; i < 40000; i++) {
  const group = Math.floor(rand() * 20);
  const a = "n" + (group * 100 + Math.floor(rand() * 100));
  const b = rand() < 0.9 ? "n" + (group * 100 + Math.floor(rand() * 100)) : "n" + Math.floor(rand() * 2000);
  big.push({ src: a, dst: b, weight: 1 });
}
const t2 = Date.now();
const bigParts = louvain(big, 10);
check("louvain 2000 nodes / 40k edges", bigParts.length >= 1990 && bigParts[0].modularity > 0.6, `${new Set(bigParts.map(r => r.community)).size} communities, Q=${bigParts[0].modularity.toFixed(3)}, ${Date.now() - t2} ms`);

// ---------------------------------------------------------------- SQL UDFs (mirrored)
// inverse normal: the same rational approximation of the SQL (Acklam)
function invNorm(p) {
  const a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
  const bb = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01];
  const c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
  const d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00];
  if (p < 0.02425) { const q = Math.sqrt(-2 * Math.log(p)); return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1); }
  if (p <= 0.97575) { const q = p - 0.5, r = q * q; return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((bb[0] * r + bb[1]) * r + bb[2]) * r + bb[3]) * r + bb[4]) * r + 1); }
  const q = Math.sqrt(-2 * Math.log(1 - p));
  return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
}
const invSql = readSql("stats/inverse_normal_cdf.sqlx");
check("inverse normal sql has the coefficients", ["3.969683028665376e+01", "2.938163982698783e+00", "1.328068155288572e+01", "3.754408661907416e+00", "0.02425", "0.97575"].every(s => invSql.includes(s)));
check("inverse normal 0.975 = 1.96", close(invNorm(0.975), 1.959963985, 1e-8), invNorm(0.975).toFixed(9));
check("inverse normal 0.8 = 0.8416", close(invNorm(0.8), 0.841621234, 1e-8));
check("inverse normal tails", close(invNorm(0.001), -3.090232306, 1e-7) && close(invNorm(0.999), 3.090232306, 1e-7));
check("inverse normal symmetric", close(invNorm(0.3) + invNorm(0.7), 0, 1e-9));

function sampleSize(p1, mde, alpha, power) {
  const p2 = p1 * (1 + mde), pbar = (p1 + p2) / 2;
  const za = invNorm(1 - alpha / 2), zb = invNorm(power);
  return Math.ceil(Math.pow(za * Math.sqrt(2 * pbar * (1 - pbar)) + zb * Math.sqrt(p1 * (1 - p1) + p2 * (1 - p2)), 2) / Math.pow(p2 - p1, 2));
}
function mde(p, n, alpha, power) {
  const za = invNorm(1 - alpha / 2), zb = invNorm(power);
  const step = d => {
    const m = Math.min(p + d / 2, 0.999999), q = Math.min(p + d, 0.999999);
    return (za * Math.sqrt(2 * m * (1 - m)) + zb * Math.sqrt(p * (1 - p) + q * (1 - q))) / Math.sqrt(n);
  };
  const d1 = (za + zb) * Math.sqrt(2 * p * (1 - p) / n);
  return step(step(d1)) / p;
}
const ssSql = readSql("stats/sample_size_proportions.sqlx");
check("sample size sql has the formula", ssSql.includes("za * SQRT(2 * pbar * (1 - pbar)) + zb * SQRT(p1 * (1 - p1) + p2 * (1 - p2))"));
check("sample size 5% baseline, 20% lift = 8158 (Evan Miller)", sampleSize(0.05, 0.2, 0.05, 0.8) === 8158, String(sampleSize(0.05, 0.2, 0.05, 0.8)));
const mdeSql = readSql("stats/mde_proportions.sqlx");
check("mde sql has three iterations", (mdeSql.match(/za \* SQRT\(2 \* m/g) || []).length === 2 && mdeSql.includes("(za + zb) * SQRT(2 * p * (1 - p) / n)"));
[[0.02, 20000], [0.05, 8158], [0.3, 1500], [0.002, 400000]].forEach(([p, n]) => {
  const rel = mde(p, n, 0.05, 0.8);
  const back = sampleSize(p, rel, 0.05, 0.8);
  check(`mde is the inverse of the sample size (p=${p}, n=${n})`, Math.abs(back - n) / n < 0.01, `mde=${(rel * 100).toFixed(2)}% -> n=${back}`);
});

const poissonSql = readSql("stats/poisson_bootstrap_weight.sqlx");
let cdf = 0, fact = 1;
const thresholds = [];
for (let k = 0; k <= 8; k++) { if (k > 0) fact *= k; cdf += Math.exp(-1) / fact; thresholds.push(cdf); }
check("poisson bootstrap thresholds are the Poisson(1) CDF", thresholds.every(t => poissonSql.includes(String(t).slice(0, 14))), thresholds.map(t => t.toFixed(6)).join(" "));

// token overlap: the same normalization of the SQL
function tokens(text) {
  const norm = String(text || "").toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
  return [...new Set((norm.match(/[a-z0-9]{3,}/g) || []).map(t => t.replace(/^([a-z0-9]{3,})s$/, "$1")))];
}
function overlap(a, b) {
  const ta = tokens(a), tb = tokens(b);
  const shared = ta.filter(t => tb.includes(t)).length;
  const union = new Set(ta.concat(tb)).size;
  return { jaccard: union ? shared / union : null, coverage: ta.length ? shared / ta.length : null };
}
const tokenSql = readSql("urls_text/token_overlap.sqlx");
check("token overlap sql has the same normalization", tokenSql.includes("r'[a-z0-9]{3,}'") && tokenSql.includes("r'^([a-z0-9]{3,})s$'") && tokenSql.includes("r'\\p{M}'"));
check("token overlap accents and slugs", overlap("tênis de corrida", "/tenis-corrida-masculino").coverage === 1);
check("token overlap plurals", overlap("camisetas pretas", "Camiseta Preta Básica").coverage === 1);
check("token overlap unrelated", overlap("geladeira frost free", "/tenis-corrida").coverage === 0);
check("token overlap jaccard", close(overlap("tenis corrida", "tenis corrida masculino").jaccard, 2 / 3, 1e-9));

console.log(failures === 0 ? "\nALL GOOD" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
