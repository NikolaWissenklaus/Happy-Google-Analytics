// author: Francisco Lucas / Nikola Wissenklaus / Chico

// constants.js
//
// Every knob from workflow_settings.yaml is parsed here, and only here.
// Dataform hands us all vars as strings, so "false" is truthy if you are not careful
// (yes, I turned on a module by accident once because of that). The models must use
// constants.SOMETHING and never touch dataform.projectConfig.vars directly.

const vars = (dataform.projectConfig && dataform.projectConfig.vars) || {};

function getVar(name, fallback) {
  const value = vars[name];
  if (value === undefined || value === null || String(value).trim() === "") return fallback;
  return String(value).trim();
}

function getBool(name, fallback) {
  const value = getVar(name, null);
  if (value === null) return fallback;
  return ["true", "1", "yes", "y", "sim", "on"].includes(value.toLowerCase());
}

function getInt(name, fallback) {
  const value = parseInt(getVar(name, ""), 10);
  return Number.isNaN(value) ? fallback : value;
}

function getList(name, fallback) {
  const value = getVar(name, null);
  if (value === null) return fallback;
  return value.split(",").map(v => v.trim().toLowerCase()).filter(v => v.length > 0);
}

// fail at compile time instead of failing at 3am inside BigQuery
function mustBeDate(name, value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`var "${name}" must look like YYYY-MM-DD, got "${value}"`);
  }
  return value;
}

const PROJECT = dataform.projectConfig.defaultDatabase;
const LOCATION = dataform.projectConfig.defaultLocation;

// ------------------------------------------------------------------ GA4 export
const GA4_PROJECT = getVar("ga4_project", PROJECT);
const GA4_DATASET = getVar("ga4_dataset", "analytics_000000000");
const TIMEZONE = getVar("property_timezone", "America/Sao_Paulo");
const CURRENCY = getVar("property_currency", "BRL").toUpperCase();
const SITE_HOSTNAMES = getList("site_hostnames", []);

// ------------------------------------------------------------------ processing
const START_DATE = mustBeDate("start_date", getVar("start_date", "2024-01-01"));
const LOOKBACK_DAYS = getInt("lookback_days", 3);
const AUTO_BACKFILL_MAX_DAYS = getInt("auto_backfill_max_days", 30);
const INCLUDE_INTRADAY = getBool("include_intraday", false);
const EXCLUDE_INTERNAL = getBool("exclude_internal_traffic", true);
const EXCLUDE_DEBUG = getBool("exclude_debug_traffic", true);
const MASK_PII = getBool("mask_pii_in_urls", true);
// bots stay in core (flagged) and the GA4/UA replica reports keep them (to match the UI).
// business marts drop them when this is true
const EXCLUDE_BOTS_IN_MARTS = getBool("exclude_bots_in_marts", true);
const MART_WINDOW_DAYS = getInt("mart_window_days", 400);

// ------------------------------------------------------------------ attribution
const SESSION_LOOKBACK_DAYS = getInt("session_lookback_days", 90);
const CONVERSION_LOOKBACK_DAYS = getInt("conversion_lookback_days", 30);
const TIME_DECAY_HALF_LIFE_DAYS = getInt("time_decay_half_life_days", 7);
// which channel grouping the attribution models use: default (GA4 compatible) or custom
const ATTRIBUTION_GROUPING = getVar("attribution_channel_grouping", "default");

// GA4 rule: engaged session = 10s+ or 2+ views or a key event
const ENGAGED_SESSION_MSEC = 10000;

// ------------------------------------------------------------------ optional modules
const ENABLE = {
  bqml: getBool("enable_bqml", false),
  google_ads: getBool("enable_google_ads", false),
  meta_ads: getBool("enable_meta_ads", false),
  search_console: getBool("enable_search_console", false),
  crm: getBool("enable_crm", false),
  user_export: getBool("enable_user_export", false),
  dsr_deletion: getBool("enable_dsr_deletion", false),
  retention_purge: getBool("enable_retention_purge", false)
};
// paid media marts need at least one cost source. manual costs (cfg_costs.js) always exist
ENABLE.paid_media = ENABLE.google_ads || ENABLE.meta_ads;

const GOOGLE_ADS = {
  project: getVar("google_ads_project", PROJECT),
  dataset: getVar("google_ads_dataset", "google_ads"),
  customer_id: getVar("google_ads_customer_id", "0000000000").replace(/-/g, "")
};

const META_ADS = {
  project: getVar("meta_ads_project", PROJECT),
  dataset: getVar("meta_ads_dataset", "meta_ads"),
  table: getVar("meta_ads_table", "ads_insights")
};

const SEARCH_CONSOLE = {
  project: getVar("search_console_project", PROJECT),
  dataset: getVar("search_console_dataset", "searchconsole")
};

const CRM = {
  project: getVar("crm_project", PROJECT),
  dataset: getVar("crm_dataset", "crm"),
  orders_table: getVar("crm_orders_table", "orders"),
  customers_table: getVar("crm_customers_table", "customers")
};

const PRIVACY = {
  retention_months: getInt("data_retention_months", 26),
  pii_scan_days: getInt("pii_scan_days", 7),
  dsr_table: getVar("dsr_table", ""),
  // the GA4 User Deletion API does NOT touch the BigQuery export, so the raw shards
  // have to be cleaned by us. separate flags because this is the point of no return
  dsr_include_raw_export: getBool("dsr_include_raw_export", false),
  retention_include_raw_export: getBool("retention_include_raw_export", false)
};

// ------------------------------------------------------------------ datasets
// one dataset per layer/context, so permissions can be given per area
// (marketing people dont need to see the privacy dataset, and so on)
const SCHEMA_PREFIX = getVar("schema_prefix", "ga4");
const schema = suffix => `${SCHEMA_PREFIX}_${suffix}`;

const SCHEMAS = {
  udf: schema("udf"),
  seeds: schema("seeds"),
  staging: schema("staging"),
  intermediate: schema("intermediate"),
  core: schema("core"),
  marketing: schema("marketing"),
  attribution: schema("attribution"),
  ecommerce: schema("ecommerce"),
  promotions: schema("promotions"),
  product: schema("product"),
  business: schema("business"),
  cro: schema("cro"),
  seo: schema("seo"),
  funnels: schema("funnels"),
  cohorts: schema("cohorts"),
  segments: schema("segments"),
  audiences: schema("audiences"),
  crm: schema("crm"),
  lifts: schema("lifts"),
  reports_ga4: schema("reports"),
  reports_ua: schema("reports_ua"),
  ds: schema("data_science"),
  dq: schema("data_quality"),
  anomaly: schema("anomaly"),
  privacy: schema("privacy"),
  watch: schema("watch"),
  governance: schema("governance"),
  ops: schema("ops"),
  activation: schema("activation")
};

// fully qualified name of something inside the GA4 export dataset
// (INFORMATION_SCHEMA, __TABLES__...). Not a ref() on purpose, those are metadata.
function ga4Table(name) {
  return `\`${GA4_PROJECT}.${GA4_DATASET}.${name}\``;
}

// same thing for any dataset of this project
function projectTable(dataset, name) {
  return `\`${PROJECT}.${dataset}.${name}\``;
}

// region level INFORMATION_SCHEMA (TABLES, COLUMNS, TABLE_STORAGE, JOBS_BY_PROJECT...)
// of this project. regionTable("COLUMNS") -> `proj.region-us.INFORMATION_SCHEMA.COLUMNS`
function regionTable(view) {
  return `\`${PROJECT}.region-${String(LOCATION).toLowerCase()}.INFORMATION_SCHEMA.${view}\``;
}

module.exports = {
  PROJECT,
  LOCATION,
  GA4_PROJECT,
  GA4_DATASET,
  TIMEZONE,
  CURRENCY,
  SITE_HOSTNAMES,
  START_DATE,
  LOOKBACK_DAYS,
  AUTO_BACKFILL_MAX_DAYS,
  INCLUDE_INTRADAY,
  EXCLUDE_INTERNAL,
  EXCLUDE_DEBUG,
  MASK_PII,
  EXCLUDE_BOTS_IN_MARTS,
  MART_WINDOW_DAYS,
  SESSION_LOOKBACK_DAYS,
  CONVERSION_LOOKBACK_DAYS,
  TIME_DECAY_HALF_LIFE_DAYS,
  ATTRIBUTION_GROUPING,
  ENGAGED_SESSION_MSEC,
  ENABLE,
  GOOGLE_ADS,
  META_ADS,
  SEARCH_CONSOLE,
  CRM,
  PRIVACY,
  SCHEMA_PREFIX,
  SCHEMAS,
  ga4Table,
  projectTable,
  regionTable,
  getVar
};
