// author: Francisco Lucas / Nikola Wissenklaus / Chico

// GA4 BigQuery export (the raw stuff).
//
// events_* also matches events_intraday_* and events_fresh_* (GA4 360).
// staging filters _TABLE_SUFFIX with 8 digits, so only the daily shards are read there.

const ga4 = { database: constants.GA4_PROJECT, schema: constants.GA4_DATASET };

declare({
  ...ga4,
  name: "events_*",
  description: "GA4 daily export shards (events_YYYYMMDD). Read only by stg_ga4__events and the watch/privacy scanners"
});

declare({
  ...ga4,
  name: "events_intraday_*",
  description: "GA4 streaming export (events_intraday_YYYYMMDD). Only used when include_intraday = true"
});

declare({
  ...ga4,
  name: "pseudonymous_users_*",
  description: "GA4 user data export by user_pseudo_id (optional, enable_user_export)"
});

declare({
  ...ga4,
  name: "users_*",
  description: "GA4 user data export by user_id (optional, enable_user_export)"
});
