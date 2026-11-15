// author: Francisco Lucas / Nikola Wissenklaus / Chico

// ga4.js
//
// GA4 export specific SQL builders: param extraction, url parsing, cleaning.
// These are inlined in the pipeline (no UDF call = no extra dependency, BigQuery
// optimizes better). The same logic exists as persistent UDFs in ga4_udf for analysts.

const constants = require("./constants");
const privacy = require("./privacy");

// ------------------------------------------------------------------ params

// value types: string | int | number | any
// "number" is for things like value/price that some sites send as int, others as double
// and the brave ones as string ("199,90" -> NULL, sorry)
function param(key, type = "string", field = "event_params") {
  const k = String(key).replace(/'/g, "");
  const from = `FROM UNNEST(${field}) WHERE key = '${k}' LIMIT 1`;
  switch (type) {
    case "string":
      return `(SELECT value.string_value ${from})`;
    case "int":
      return `(SELECT COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64), SAFE_CAST(value.double_value AS INT64), SAFE_CAST(value.float_value AS INT64)) ${from})`;
    case "number":
      return `(SELECT COALESCE(value.double_value, value.float_value, CAST(value.int_value AS FLOAT64), SAFE_CAST(value.string_value AS FLOAT64)) ${from})`;
    case "any":
      return `(SELECT COALESCE(value.string_value, CAST(value.int_value AS STRING), CAST(value.double_value AS STRING), CAST(value.float_value AS STRING)) ${from})`;
    default:
      throw new Error(`ga4.param: unknown type ${type}`);
  }
}

const paramStr = key => param(key, "string");
const paramInt = key => param(key, "int");
const paramNum = key => param(key, "number");
const paramAny = key => param(key, "any");
const userProp = (key, type = "any") => param(key, type, "user_properties");
const itemParam = (key, type = "any", alias = "i") => param(key, type, `${alias}.item_params`);

// ------------------------------------------------------------------ urls

function urlParam(urlExpr, key) {
  return `REGEXP_EXTRACT(${urlExpr}, r'(?i)[?&#]${key}=([^&#]*)')`;
}

// utm values come url encoded sometimes ("black+friday", "black%20friday")
function utmValue(urlExpr, key) {
  return `NULLIF(LOWER(TRIM(REPLACE(REPLACE(REPLACE(${urlParam(urlExpr, key)}, '+', ' '), '%20', ' '), '%7C', '|'))), '')`;
}

function urlHost(urlExpr) {
  return `LOWER(NET.HOST(${urlExpr}))`;
}

// "/Produto/Tenis-X/?utm=1#top" -> "/produto/tenis-x"
function urlPath(urlExpr) {
  return `COALESCE(NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(LOWER(REGEXP_EXTRACT(${urlExpr}, r'^(?:[a-zA-Z][a-zA-Z0-9+.-]*://[^/?#]*)?([^?#]*)')), r'/{2,}', '/'), r'(.)/+$', '\\\\1'), ''), '/')`;
}

function urlQuery(urlExpr) {
  return `REGEXP_EXTRACT(${urlExpr}, r'\\?([^#]*)')`;
}

// ------------------------------------------------------------------ cleaning

// junk values that GA4 (or the dev team) sends instead of NULL
const JUNK = ["", "(not set)", "not set", "(not provided)", "undefined", "null", "nan", "[object object]", "none"];
const JUNK_IDS = JUNK.concat(["0", "-", "n/a", "na", "unknown"]);

function cleanString(expr) {
  return `IF(LOWER(TRIM(${expr})) IN (${JUNK.map(v => `'${v}'`).join(", ")}), NULL, TRIM(${expr}))`;
}

function cleanId(expr) {
  return `IF(LOWER(TRIM(CAST(${expr} AS STRING))) IN (${JUNK_IDS.map(v => `'${v}'`).join(", ")}), NULL, TRIM(CAST(${expr} AS STRING)))`;
}

// traffic values: lower + trim + junk removal. keeps "(direct)" and "(none)" because they mean something
function cleanTraffic(expr) {
  return `NULLIF(IF(LOWER(TRIM(${expr})) IN ('', '(not set)', 'not set', 'undefined', 'null', '(not provided)'), NULL, LOWER(TRIM(${expr}))), '')`;
}

function sessionKey(pseudoExpr, sessionIdExpr) {
  return `IF(${pseudoExpr} IS NULL OR ${sessionIdExpr} IS NULL, NULL, CONCAT(${pseudoExpr}, '.', CAST(${sessionIdExpr} AS STRING)))`;
}

// privacy_info comes as 'Yes'/'No'/NULL. we use granted/denied/unknown everywhere
function consentState(expr) {
  return `CASE LOWER(${expr}) WHEN 'yes' THEN 'granted' WHEN 'granted' THEN 'granted' WHEN 'true' THEN 'granted' WHEN 'no' THEN 'denied' WHEN 'denied' THEN 'denied' WHEN 'false' THEN 'denied' ELSE 'unknown' END`;
}

// ------------------------------------------------------------------ raw export columns

// explicit list instead of SELECT *, so daily and intraday can be unioned by position
// and a new column from google doesnt break the union. if your export is older than
// jul/2024 and doesnt have session_traffic_source_last_click, see docs/troubleshooting.md
const RAW_EVENT_COLUMNS = [
  "event_date",
  "event_timestamp",
  "event_name",
  "event_params",
  "event_previous_timestamp",
  "event_value_in_usd",
  "event_bundle_sequence_id",
  "event_server_timestamp_offset",
  "user_id",
  "user_pseudo_id",
  "privacy_info",
  "user_properties",
  "user_first_touch_timestamp",
  "user_ltv",
  "device",
  "geo",
  "app_info",
  "traffic_source",
  "stream_id",
  "platform",
  "event_dimensions",
  "ecommerce",
  "items",
  "collected_traffic_source",
  "is_active_user",
  "batch_event_index",
  "batch_page_id",
  "batch_ordering_id",
  "session_traffic_source_last_click"
];

function rawEventColumns() {
  return RAW_EVENT_COLUMNS.join(",\n    ");
}

// GA4 has no event id. exact duplicates (same everything) collapse to the same id,
// two real events in the same batch differ by batch_event_index / params.
function eventIdExpr() {
  return `FARM_FINGERPRINT(CONCAT(
      COALESCE(user_pseudo_id, ''), '|',
      CAST(event_timestamp AS STRING), '|',
      event_name, '|',
      COALESCE(CAST(event_bundle_sequence_id AS STRING), ''), '|',
      COALESCE(CAST(batch_event_index AS STRING), ''), '|',
      COALESCE(stream_id, ''), '|',
      TO_JSON_STRING(event_params)
    ))`;
}

// rebuild event_params / user_properties with masked string values
function maskedParams(field) {
  if (!constants.MASK_PII) return field;
  return `ARRAY(
      SELECT AS STRUCT
        p.key,
        STRUCT(${privacy.maskText("p.value.string_value")} AS string_value, p.value.int_value, p.value.float_value, p.value.double_value) AS value
      FROM UNNEST(${field}) AS p WITH OFFSET AS pos
      ORDER BY pos
    )`;
}

function maskedUserProperties(field) {
  if (!constants.MASK_PII) return field;
  return `ARRAY(
      SELECT AS STRUCT
        p.key,
        STRUCT(${privacy.maskText("p.value.string_value")} AS string_value, p.value.int_value, p.value.float_value, p.value.double_value, p.value.set_timestamp_micros) AS value
      FROM UNNEST(${field}) AS p WITH OFFSET AS pos
      ORDER BY pos
    )`;
}

function maybeMask(expr) {
  return constants.MASK_PII ? privacy.maskText(expr) : expr;
}

module.exports = {
  param,
  paramStr,
  paramInt,
  paramNum,
  paramAny,
  userProp,
  itemParam,
  urlParam,
  utmValue,
  urlHost,
  urlPath,
  urlQuery,
  cleanString,
  cleanId,
  cleanTraffic,
  sessionKey,
  consentState,
  RAW_EVENT_COLUMNS,
  rawEventColumns,
  eventIdExpr,
  maskedParams,
  maskedUserProperties,
  maybeMask
};
