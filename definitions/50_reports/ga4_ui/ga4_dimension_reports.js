// author: Francisco Lucas / Nikola Wissenklaus / Chico

// GA4 UI standard reports rebuilt as daily tables (Reports > Acquisition / Engagement / Demographics / Tech).
// Same metric definitions of the interface. Users: use the *_hll columns to sum days (HLL_COUNT.MERGE).

const schema = constants.SCHEMAS.reports_ga4;

reports.incrementalReport({
  name: "rpt_ga4_traffic_acquisition_daily",
  schema,
  description: "GA4 Reports > Acquisition > Traffic acquisition: session default channel group, source / medium, campaign with users, sessions, engaged sessions, engagement time, events per session, key events and revenue",
  flavor: "ga4",
  dims: [
    { expr: "s.session_default_channel_group", alias: "session_default_channel_group" },
    { expr: "s.session_source", alias: "session_source" },
    { expr: "s.session_medium", alias: "session_medium" },
    { expr: "COALESCE(s.session_campaign, '(not set)')", alias: "session_campaign" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_user_acquisition_daily",
  schema,
  description: "GA4 Reports > Acquisition > User acquisition: everything grouped by the FIRST user source / medium / campaign (GA4 traffic_source of the export) and our first channel of the stitched user",
  flavor: "ga4",
  dims: [
    { expr: "COALESCE(u.first_channel, '(not set)')", alias: "first_user_default_channel_group" },
    { expr: "COALESCE(s.ga4_first_user_source, u.first_source, '(not set)')", alias: "first_user_source" },
    { expr: "COALESCE(s.ga4_first_user_medium, u.first_medium, '(not set)')", alias: "first_user_medium" },
    { expr: "COALESCE(s.ga4_first_user_campaign, u.first_campaign, '(not set)')", alias: "first_user_campaign" }
  ],
  joins: ctx => `LEFT JOIN ${ctx.ref("dim_users")} AS u ON u.user_key = s.user_key`
});

reports.incrementalReport({
  name: "rpt_ga4_demographics_daily",
  schema,
  description: "GA4 Reports > User attributes > Demographic details: country, region (+ UF for Brazil), city and language",
  flavor: "ga4",
  dims: [
    { expr: "COALESCE(s.geo_country, '(not set)')", alias: "country" },
    { expr: "COALESCE(s.geo_region, '(not set)')", alias: "region" },
    { expr: "COALESCE(s.geo_uf, '(n/a)')", alias: "uf" },
    { expr: "COALESCE(s.geo_city, '(not set)')", alias: "city" },
    { expr: "COALESCE(s.device_language, '(not set)')", alias: "language" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_tech_daily",
  schema,
  description: "GA4 Reports > Tech > Tech details: platform, device category, operating system (+ version), browser and app version",
  flavor: "ga4",
  dims: [
    { expr: "s.platform", alias: "platform" },
    { expr: "COALESCE(s.device_category, '(not set)')", alias: "device_category" },
    { expr: "COALESCE(s.device_os, '(not set)')", alias: "operating_system" },
    { expr: "COALESCE(s.device_os_version, '(not set)')", alias: "os_version" },
    { expr: "COALESCE(s.device_browser, '(not set)')", alias: "browser" },
    { expr: "COALESCE(s.app_version, '(not set)')", alias: "app_version" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_free_form_cube_daily",
  schema,
  description: "Free form exploration cube: date x channel x device x country x new/returning x landing page type with every GA4 metric. 80% of the explorations people build by hand fit in this table",
  flavor: "ga4",
  dims: [
    { expr: "s.session_default_channel_group", alias: "session_default_channel_group" },
    { expr: "COALESCE(s.device_category, '(not set)')", alias: "device_category" },
    { expr: "COALESCE(s.geo_country, '(not set)')", alias: "country" },
    { expr: "IF(s.is_new_user, 'new', 'returning')", alias: "new_vs_returning" },
    { expr: "s.landing_page_type", alias: "landing_page_type" }
  ]
});
