// author: Francisco Lucas / Nikola Wissenklaus / Chico

// More GA4 UI standard reports with the same builder of ga4_dimension_reports.js
// (same metric names, bots kept, *_hll columns to sum days).
// These are the dimensions people keep adding by hand in the "+" of the GA4 tables.

const schema = constants.SCHEMAS.reports_ga4;

reports.incrementalReport({
  name: "rpt_ga4_custom_channel_acquisition_daily",
  schema,
  description: "GA4 Reports > Acquisition > Traffic acquisition with 'Session primary channel group' = our custom channel group (AI assistants, WhatsApp, Brand x Non-brand...) next to the default one. The report the marketing team really reads",
  flavor: "ga4",
  dims: [
    { expr: "s.session_custom_channel_group", alias: "session_primary_channel_group" },
    { expr: "s.session_default_channel_group", alias: "session_default_channel_group" },
    { expr: "COALESCE(s.device_category, '(not set)')", alias: "device_category" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_manual_campaigns_daily",
  schema,
  description: "GA4 Reports > Acquisition > Traffic acquisition with the manual (utm) dimensions: session manual source, medium, campaign, campaign id, term and ad content. The utm_content / utm_term view the agencies ask for",
  flavor: "ga4",
  dims: [
    { expr: "s.session_source", alias: "session_manual_source" },
    { expr: "s.session_medium", alias: "session_manual_medium" },
    { expr: "COALESCE(s.session_campaign, '(not set)')", alias: "session_manual_campaign_name" },
    { expr: "COALESCE(s.session_campaign_id, '(not set)')", alias: "session_manual_campaign_id" },
    { expr: "COALESCE(s.session_term, '(not set)')", alias: "session_manual_term" },
    { expr: "COALESCE(s.session_content, '(not set)')", alias: "session_manual_ad_content" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_google_ads_campaigns_daily",
  schema,
  description: "GA4 Reports > Acquisition > Google Ads campaigns (GA4 linked to Google Ads): sessions and results per Google Ads campaign, ad group and keyword / term. Only sessions that came from Google Ads (google / cpc or with the Google Ads ids of the export)",
  flavor: "ga4",
  dims: [
    { expr: "COALESCE(s.google_ads_campaign_id, s.session_campaign_id, '(not set)')", alias: "session_google_ads_campaign_id" },
    { expr: "COALESCE(s.google_ads_campaign_name, s.session_campaign, '(not set)')", alias: "session_google_ads_campaign_name" },
    { expr: "COALESCE(s.google_ads_ad_group_name, '(not set)')", alias: "session_google_ads_ad_group_name" },
    { expr: "COALESCE(s.session_term, '(not set)')", alias: "session_google_ads_keyword_text" },
    { expr: "COALESCE(s.device_category, '(not set)')", alias: "device_category" }
  ],
  where: "AND (s.google_ads_campaign_id IS NOT NULL OR (s.session_source = 'google' AND s.session_medium = 'cpc'))"
});

reports.incrementalReport({
  name: "rpt_ga4_device_models_daily",
  schema,
  description: "GA4 Reports > Tech > Tech details with device brand and device model (the one that finds the cheap android where the checkout breaks), plus OS and browser",
  flavor: "ga4",
  dims: [
    { expr: "COALESCE(s.device_category, '(not set)')", alias: "device_category" },
    { expr: "COALESCE(s.device_brand, '(not set)')", alias: "mobile_device_branding" },
    { expr: "COALESCE(s.device_model, '(not set)')", alias: "mobile_device_model" },
    { expr: "COALESCE(s.device_os, '(not set)')", alias: "operating_system" },
    { expr: "COALESCE(s.device_browser, '(not set)')", alias: "browser" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_hostnames_daily",
  schema,
  description: "Free form with the Hostname dimension: sessions and results per hostname of the session and of the landing page. Finds checkout on another domain, staging leaking the production tag and ghost hosts (is_non_production_host)",
  flavor: "ga4",
  dims: [
    { expr: "COALESCE(s.hostname, '(not set)')", alias: "hostname" },
    { expr: "COALESCE(s.landing_hostname, '(not set)')", alias: "landing_hostname" },
    { expr: "COALESCE(s.is_non_production_host, FALSE)", alias: "is_non_production_host" }
  ]
});

reports.incrementalReport({
  name: "rpt_ga4_new_established_daily",
  schema,
  description: "GA4 Reports > Retention style split by session number band (1st, 2nd, 3-5, 6-10, 11+) and channel: how the value of a visit grows with the relationship. GA4 only shows new vs returning, this shows the whole curve",
  flavor: "ga4",
  dims: [
    {
      expr: `CASE
        WHEN s.session_number <= 1 THEN '01 first'
        WHEN s.session_number = 2 THEN '02 second'
        WHEN s.session_number <= 5 THEN '03 3-5'
        WHEN s.session_number <= 10 THEN '04 6-10'
        ELSE '05 11+'
      END`,
      alias: "session_number_band"
    },
    { expr: "s.session_default_channel_group", alias: "session_default_channel_group" }
  ]
});
