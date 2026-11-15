// author: Francisco Lucas / Nikola Wissenklaus / Chico

// docs.js
//
// Column descriptions reused by many tables. They go to BigQuery as column
// descriptions, so people using Looker Studio / Sheets see them too.
// Usage in a SQLX config: columns: docs.pick("session_key", "user_key", "session_date")

const common = {
  event_id: "Our event id (FARM_FINGERPRINT of the raw row). GA4 has no event id, exact duplicates get the same one",
  event_date: "Event date in the property timezone (same as the export shard)",
  event_ts: "Event timestamp (UTC)",
  event_datetime_local: "Event date time in the property timezone",
  event_name: "GA4 event name",
  user_pseudo_id: "GA4 device/browser id (client id on web, app instance id on apps)",
  user_id: "Logged user id sent by the site (cleaned: '', 'undefined', 'null', '0' become NULL)",
  user_key: "Stitched user: 'uid:<user_id>' when the device was ever logged in, else 'dev:<user_pseudo_id>'",
  ga_session_id: "GA4 session id (unix seconds of the session start). Not unique alone!",
  session_key: "user_pseudo_id + '.' + ga_session_id. The real session id",
  session_date: "Date of the first event of the session (property timezone)",
  session_start_ts: "Timestamp of the first event of the session",
  session_number: "Session count of the device. GA4 ga_session_number, rebuilt when missing",
  is_new_user: "First session of the device (session_number = 1 or first_visit/first_open in the session)",
  is_engaged: "Engaged session, GA4 flag OR the rule (10s+, 2+ views or key event) when the flag is missing",
  is_bounce_ga4: "GA4 bounce = not engaged",
  is_bounce_ua: "Universal Analytics bounce = one page view and no interaction event",
  session_source: "Session source, last non-direct click (GA4 style, with carry over from previous sessions)",
  session_medium: "Session medium, last non-direct click",
  session_campaign: "Session campaign, last non-direct click",
  session_default_channel_group: "GA4 default channel group rules applied on the fixed session source/medium/campaign",
  session_custom_channel_group: "Custom channel group (AI Assistants, WhatsApp, Marketplaces, Cashback, Brand x Non-brand...)",
  landing_page_path: "First page of the session. Falls back to the first event with page_location when there is no page_view",
  device_category: "desktop / mobile / tablet / smart tv",
  geo_country: "Country (GA4 geo, IP based)",
  geo_region: "Region / state as GA4 writes it",
  geo_uf: "Brazilian state code (SP, RJ...) derived from geo_region. NULL outside Brazil",
  consent_analytics_storage: "granted / denied / unknown, from privacy_info",
  consent_ads_storage: "granted / denied / unknown, from privacy_info",
  transaction_id: "Transaction id, cleaned. Missing ids become 'missing-<event_id>'",
  revenue: "Purchase revenue in property currency, fixed: purchase_revenue, else value param, else sum of items",
  loaded_at: "When this row was written by Dataform",
  users_hll: "HLL sketch of users. Sum days with HLL_COUNT.MERGE(users_hll) instead of summing users",
  sessions: "Number of sessions",
  users: "Distinct users (user_pseudo_id) in the grain of the row",
  engaged_sessions: "Sessions with is_engaged = TRUE",
  transactions: "Distinct transactions (deduplicated, test transactions excluded)",
  key_events: "Key events counted with the GA4 counting method configured in cfg_key_events.js",
  conversion_rate: "transactions / sessions",
  data_quality_score: "0-100 trust score of the row. 100 = nothing weird found"
};

function pick(...names) {
  const out = {};
  names.forEach(name => {
    if (!common[name]) throw new Error(`docs.pick: no description for column "${name}"`);
    out[name] = common[name];
  });
  return out;
}

module.exports = { common, pick };
