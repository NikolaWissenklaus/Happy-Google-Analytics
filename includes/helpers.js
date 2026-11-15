// author: Francisco Lucas / Nikola Wissenklaus / Chico

// helpers.js
//
// Small generic SQL builders used all over the project.
// Rule of thumb: if a snippet shows up in 3+ models it comes to live here.
// GA4 specific stuff is in ga4.js, channel logic in channels.js.

const constants = require("./constants");

// ------------------------------------------------------------------ literals

// JS value -> BigQuery string literal (single quotes, escaped)
function sqlString(value) {
  if (value === null || value === undefined) return "NULL";
  return "'" + String(value).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
}

function sqlList(values) {
  return (values || []).map(sqlString).join(", ");
}

// expr IN ('a', 'b') but safe for empty lists (IN () is a syntax error)
function inList(expr, values) {
  if (!values || values.length === 0) return "FALSE";
  return `${expr} IN (${sqlList(values)})`;
}

// escape a literal so it can go inside a RE2 regex
function regexEscape(value) {
  return String(value).replace(/'/g, "").replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
}

// ^(a|b|c)$ from a list. exact=false gives a "contains any" regex
function regexFromList(values, exact = true) {
  const body = (values || []).map(regexEscape).join("|");
  if (!body) return exact ? "^$" : "a^"; // a^ never matches, on purpose
  return exact ? `^(${body})$` : `(${body})`;
}

// ------------------------------------------------------------------ dates

function today() {
  return `CURRENT_DATE('${constants.TIMEZONE}')`;
}

function daysAgo(days) {
  return `DATE_SUB(${today()}, INTERVAL ${days} DAY)`;
}

// heavy marts dont need 5 years of data every day
function martWindowStart(days = constants.MART_WINDOW_DAYS) {
  return `GREATEST(DATE '${constants.START_DATE}', ${daysAgo(days)})`;
}

function weekStart(dateExpr) {
  return `DATE_TRUNC(${dateExpr}, WEEK(MONDAY))`;
}

// ------------------------------------------------------------------ incremental pattern
//
// Every incremental model in this repo works the same way:
//   1. run_from = (max date already loaded - lookback), or start_date on full refresh
//   2. if some upstream model reprocessed older days after our last load, go back further
//      (that's the "auto backfill": GA4 rewrites old shards sometimes and we follow it)
//   3. DELETE everything >= run_from and INSERT it again (idempotent, handles late hits)
//   4. post op writes our run_from in ops_incremental_watermarks so the models
//      downstream know what we touched.
//
// DECLAREs must be the first statements of a BigQuery script, that's why the model
// can pass its own extra DECLAREs through `declares` and they go before any SET/DELETE.

// part 1: only DECLAREs (run_from + upstream watermark)
function incrementalDeclares({ self, incremental, model, dateColumn, watermarks, upstream = [], lookbackDays = constants.LOOKBACK_DAYS }) {
  const start = `DATE '${constants.START_DATE}'`;
  const lines = [];
  if (incremental) {
    lines.push(`DECLARE run_from DATE DEFAULT (
    SELECT COALESCE(DATE_SUB(MAX(${dateColumn}), INTERVAL ${lookbackDays} DAY), ${start})
    FROM ${self}
  );`);
  } else {
    lines.push(`DECLARE run_from DATE DEFAULT ${start};`);
  }
  if (incremental && watermarks && upstream.length > 0) {
    lines.push(`DECLARE upstream_changed_from DATE DEFAULT (
    SELECT MIN(run_from)
    FROM ${watermarks}
    WHERE model IN (${sqlList(upstream)})
      AND loaded_at > COALESCE((SELECT MAX(loaded_at) FROM ${watermarks} WHERE model = '${model}'), TIMESTAMP '1970-01-01')
  );`);
  }
  return lines.join("\n  ");
}

// part 2: SETs + DELETE. goes after any extra DECLARE of the model
function incrementalApply({ self, incremental, dateColumn, watermarks, upstream = [] }) {
  const start = `DATE '${constants.START_DATE}'`;
  const lines = [];
  if (incremental && watermarks && upstream.length > 0) {
    lines.push(`SET run_from = LEAST(
    run_from,
    GREATEST(COALESCE(upstream_changed_from, run_from), DATE_SUB(${today()}, INTERVAL ${constants.AUTO_BACKFILL_MAX_DAYS} DAY))
  );`);
  }
  lines.push(`SET run_from = GREATEST(run_from, ${start});`);
  if (incremental) {
    lines.push(`DELETE FROM ${self} WHERE ${dateColumn} >= run_from;`);
  }
  return lines.join("\n  ");
}

// the usual case: everything together
function incrementalPreOps(opts) {
  return [incrementalDeclares(opts), opts.declares || "", incrementalApply(opts)].filter(s => s).join("\n  ");
}

function incrementalPostOps({ incremental, model, watermarks }) {
  if (!watermarks) return "";
  return `INSERT INTO ${watermarks} (model, run_from, run_mode, loaded_at)
  VALUES ('${model}', run_from, '${incremental ? "incremental" : "full_refresh"}', CURRENT_TIMESTAMP());`;
}

// ------------------------------------------------------------------ filters

// internal / debug traffic is kept in staging (data quality needs it) and dropped
// from sessions onwards, unless the vars say otherwise
function noiseFilter(alias = "") {
  const prefix = alias ? `${alias}.` : "";
  const parts = [];
  if (constants.EXCLUDE_INTERNAL) parts.push(`NOT ${prefix}is_internal_traffic`);
  if (constants.EXCLUDE_DEBUG) parts.push(`NOT ${prefix}is_debug`);
  return parts.length ? `AND ${parts.join(" AND ")}` : "";
}

// business marts: no bots (when exclude_bots_in_marts = true)
function martSessionFilter(alias = "") {
  const prefix = alias ? `${alias}.` : "";
  return constants.EXCLUDE_BOTS_IN_MARTS ? `AND NOT ${prefix}is_bot_suspect` : "";
}

// ------------------------------------------------------------------ math / stats snippets

function pctChange(current, previous) {
  return `SAFE_DIVIDE((${current}) - (${previous}), NULLIF(ABS(${previous}), 0))`;
}

// Wilson score interval. Way better than raw conversion rate when comparing
// a page with 3 sessions against one with 30 thousand.
function wilsonLower(successes, trials, z = 1.96) {
  const s = `CAST(${successes} AS FLOAT64)`;
  const n = `CAST(${trials} AS FLOAT64)`;
  return `IF(${n} > 0,
    ((${s} / ${n}) + ${z * z} / (2 * ${n}) - ${z} * SQRT(((${s} / ${n}) * (1 - ${s} / ${n}) + ${z * z} / (4 * ${n})) / ${n})) / (1 + ${z * z} / ${n}),
    NULL)`;
}

function wilsonUpper(successes, trials, z = 1.96) {
  const s = `CAST(${successes} AS FLOAT64)`;
  const n = `CAST(${trials} AS FLOAT64)`;
  return `IF(${n} > 0,
    ((${s} / ${n}) + ${z * z} / (2 * ${n}) + ${z} * SQRT(((${s} / ${n}) * (1 - ${s} / ${n}) + ${z * z} / (4 * ${n})) / ${n})) / (1 + ${z * z} / ${n}),
    NULL)`;
}

// ------------------------------------------------------------------ seeds
//
// Dataform has no "seeds" like dbt, so small reference tables are written as
// typed arrays. Keeps the data versioned in git together with the code.

// deterministic holdout: the same person is always in (or out of) the holdout of the same
// program, no table needed. FARM_FINGERPRINT spreads the keys evenly between 0 and 99
function isHoldout(programExpr, userKeyExpr, pct) {
  // MOD before ABS: ABS of the smallest INT64 overflows (one in 2^64, but it happens to someone)
  return `(ABS(MOD(FARM_FINGERPRINT(CONCAT(${programExpr}, ':', ${userKeyExpr})), 100)) < ${pct})`;
}

// TO_JSON_STRING writes "field":null for every NULL of the STRUCT, and some APIs (Measurement
// Protocol, Meta CAPI) refuse a null where they expect a string. This removes them.
// first the ones after a comma, then the first of an object
function jsonStripNulls(jsonExpr) {
  return `REGEXP_REPLACE(REGEXP_REPLACE(${jsonExpr}, r',"[a-zA-Z0-9_]+":null', ''), r'"[a-zA-Z0-9_]+":null,?', '')`;
}

function toSqlLiteral(value, type) {
  const t = type.toUpperCase().replace(/\s+/g, "");
  if (t.startsWith("ARRAY<")) {
    const inner = type.trim().slice(6, -1);
    const items = (value || []).map(v => toSqlLiteral(v, inner));
    return `ARRAY<${inner}>[${items.join(", ")}]`;
  }
  if (value === null || value === undefined) return `CAST(NULL AS ${type})`;
  if (t === "STRING") return sqlString(value);
  if (t === "INT64") return String(parseInt(value, 10));
  if (t === "FLOAT64" || t === "NUMERIC") return String(Number(value));
  if (t === "BOOL") return value ? "TRUE" : "FALSE";
  if (t === "DATE") return `DATE '${value}'`;
  if (t === "TIMESTAMP") return `TIMESTAMP '${value}'`;
  throw new Error(`seed type not supported: ${type}`);
}

function seedSql(columns, rows) {
  const structType = `STRUCT<${columns.map(c => `${c.name} ${c.type}`).join(", ")}>`;
  const values = (rows || []).map(row => `(${columns.map(c => toSqlLiteral(row[c.name], c.type)).join(", ")})`);
  return `SELECT * FROM UNNEST(ARRAY<${structType}>[\n  ${values.join(",\n  ")}\n])`;
}

module.exports = {
  isHoldout,
  jsonStripNulls,
  sqlString,
  sqlList,
  inList,
  regexEscape,
  regexFromList,
  today,
  daysAgo,
  martWindowStart,
  weekStart,
  incrementalDeclares,
  incrementalApply,
  incrementalPreOps,
  incrementalPostOps,
  noiseFilter,
  martSessionFilter,
  pctChange,
  wilsonLower,
  wilsonUpper,
  toSqlLiteral,
  seedSql
};
