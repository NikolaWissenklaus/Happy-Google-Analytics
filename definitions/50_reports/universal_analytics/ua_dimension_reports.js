// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Universal Analytics reports rebuilt on GA4 data (Audience / Acquisition / Behavior).
// UA metrics: sessions, users, new users, bounces (one page view and no interaction), avg session
// duration, pages per session, % new sessions, goal completions, ecommerce conversion rate.
// Daily incremental tables, users via users_hll. Bots kept (same as the old UA views, no filter).

const schema = constants.SCHEMAS.reports_ua;

// the UA default channel grouping, rules and order of the old Admin > Channel Settings.
// yes, in UA facebook / cpc was "Paid Search". we keep it, it is a replica
const uaChannel = `CASE
      WHEN s.session_source = '(direct)' AND s.session_medium IN ('(not set)', '(none)') THEN 'Direct'
      WHEN s.session_medium = 'organic' THEN 'Organic Search'
      WHEN REGEXP_CONTAINS(s.session_medium, r'^(social|social-network|social-media|sm|social network|social media)$')
        OR (${helpers.inList("s.session_source", cfg_channels.social)} AND s.session_medium = 'referral') THEN 'Social'
      WHEN s.session_medium = 'email' THEN 'Email'
      WHEN s.session_medium = 'affiliate' THEN 'Affiliates'
      WHEN s.session_medium = 'referral' THEN 'Referral'
      WHEN REGEXP_CONTAINS(s.session_medium, r'^(cpc|ppc|paidsearch)$') THEN 'Paid Search'
      WHEN REGEXP_CONTAINS(s.session_medium, r'^(cpv|cpa|cpp|content-text)$') THEN 'Other Advertising'
      WHEN REGEXP_CONTAINS(s.session_medium, r'^(display|cpm|banner)$') THEN 'Display'
      ELSE '(Other)'
    END`;

const uaReports = [
  {
    name: "rpt_ua_audience_overview_daily",
    description: "UA Audience > Overview: users, new users, sessions, pageviews, pages / session, avg session duration, bounce rate and % new sessions per day",
    dims: []
  },
  {
    name: "rpt_ua_channels_daily",
    description: "UA Acquisition > All Traffic > Channels with the ORIGINAL UA default channel grouping rules (Social, Other Advertising, (Other)...) and the GA4 group side by side",
    dims: [
      { expr: uaChannel, alias: "ua_default_channel_grouping" },
      { expr: "s.session_default_channel_group", alias: "ga4_default_channel_group" }
    ]
  },
  {
    name: "rpt_ua_source_medium_daily",
    description: "UA Acquisition > All Traffic > Source/Medium",
    dims: [{ expr: "s.session_source_medium", alias: "source_medium" }]
  },
  {
    name: "rpt_ua_campaigns_daily",
    description: "UA Acquisition > Campaigns > All Campaigns: campaign with source / medium",
    dims: [
      { expr: "COALESCE(LOWER(s.session_campaign), '(not set)')", alias: "campaign" },
      { expr: "s.session_source_medium", alias: "source_medium" }
    ]
  },
  {
    name: "rpt_ua_referrals_daily",
    description: "UA Acquisition > All Traffic > Referrals (sessions with medium = referral, session own source)",
    dims: [{ expr: "s.session_source_only", alias: "referral_source" }],
    where: "AND s.session_medium_only = 'referral'"
  },
  {
    name: "rpt_ua_landing_pages_daily",
    description: "UA Behavior > Site Content > Landing Pages with UA bounce rate (a single page view without interaction), pages per session and avg session duration",
    dims: [{ expr: "COALESCE(s.landing_page_path, '(not set)')", alias: "landing_page" }]
  },
  {
    name: "rpt_ua_browser_os_daily",
    description: "UA Audience > Technology > Browser & OS: browser, major version, operating system and version",
    dims: [
      { expr: "COALESCE(s.device_browser, '(not set)')", alias: "browser" },
      { expr: "COALESCE(REGEXP_EXTRACT(s.device_browser_version, r'^(\\d+)'), '(not set)')", alias: "browser_major_version" },
      { expr: "COALESCE(s.device_os, '(not set)')", alias: "operating_system" },
      { expr: "COALESCE(s.device_os_version, '(not set)')", alias: "operating_system_version" }
    ]
  },
  {
    name: "rpt_ua_mobile_devices_daily",
    description: "UA Audience > Mobile > Overview and Devices: device category, brand and model",
    dims: [
      { expr: "COALESCE(s.device_category, '(not set)')", alias: "device_category" },
      { expr: "COALESCE(s.device_brand, '(not set)')", alias: "mobile_device_branding" },
      { expr: "COALESCE(s.device_model, '(not set)')", alias: "mobile_device_model" }
    ]
  },
  {
    name: "rpt_ua_geo_daily",
    description: "UA Audience > Geo > Location and Language: country, region, city and language",
    dims: [
      { expr: "COALESCE(s.geo_country, '(not set)')", alias: "country" },
      { expr: "COALESCE(s.geo_region, '(not set)')", alias: "region" },
      { expr: "COALESCE(s.geo_city, '(not set)')", alias: "city" },
      { expr: "COALESCE(s.device_language, '(not set)')", alias: "language" }
    ]
  },
  {
    name: "rpt_ua_hostnames_daily",
    description: "UA Audience > Technology > Network > Hostname (the report everybody used to find ghost spam)",
    dims: [{ expr: "COALESCE(s.hostname, '(not set)')", alias: "hostname" }]
  },
  {
    name: "rpt_ua_hour_of_day_daily",
    description: "UA custom report classic: sessions and conversion by hour of the day and day of the week",
    dims: [
      { expr: "s.session_hour", alias: "hour_of_day" },
      { expr: "s.session_iso_weekday", alias: "day_of_week" }
    ]
  },
  {
    name: "rpt_ua_new_vs_returning_daily",
    description: "UA Audience > Behavior > New vs Returning",
    dims: [{ expr: "IF(s.is_new_user, 'New Visitor', 'Returning Visitor')", alias: "user_type" }]
  }
];

uaReports.forEach(r => reports.incrementalReport({
  name: r.name,
  schema,
  description: r.description,
  flavor: "ua",
  dims: r.dims,
  where: r.where || ""
}));
