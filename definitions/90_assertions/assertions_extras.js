// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Assertions of the extras pack (cfg_extras.js): grain of the new tables and math that must hold.
// Disabled models are skipped (a reference to a disabled model would break the compilation).

function checkExtra(name, description, query, extraTags = []) {
  assert(name, {
    description,
    tags: ["assertions", "daily", "extras"].concat(extraTags)
  }).query(query);
}

checkExtra("assert_extras_unique_grain",
  "The new GA4 replicas and cross data marts have one row per declared grain",
  ctx => `
SELECT 'rpt_ga4_advertising_all_channels_daily' AS model, TO_JSON_STRING(STRUCT(metric_date, default_channel_group)) AS grain, COUNT(*) AS rows_found
FROM ${ctx.ref("rpt_ga4_advertising_all_channels_daily")}
GROUP BY grain HAVING COUNT(*) > 1
UNION ALL
SELECT 'rpt_ga4_monetization_overview_daily', TO_JSON_STRING(STRUCT(metric_date)) AS grain, COUNT(*)
FROM ${ctx.ref("rpt_ga4_monetization_overview_daily")}
GROUP BY grain HAVING COUNT(*) > 1
UNION ALL
SELECT 'rpt_ga4_user_acquisition_cohort', TO_JSON_STRING(STRUCT(cohort_month, first_user_default_channel_group, month_number)) AS grain, COUNT(*)
FROM ${ctx.ref("rpt_ga4_user_acquisition_cohort")}
GROUP BY grain HAVING COUNT(*) > 1
UNION ALL
SELECT 'ecom_regional_bestsellers', TO_JSON_STRING(STRUCT(geo_uf, item_category)) AS grain, COUNT(*)
FROM ${ctx.ref("ecom_regional_bestsellers")}
GROUP BY grain HAVING COUNT(*) > 1
UNION ALL
SELECT 'ecom_launch_cannibalization', TO_JSON_STRING(STRUCT(item_id)) AS grain, COUNT(*)
FROM ${ctx.ref("ecom_launch_cannibalization")}
GROUP BY grain HAVING COUNT(*) > 1
UNION ALL
SELECT 'ecom_wishlist_to_purchase', TO_JSON_STRING(STRUCT(item_id)) AS grain, COUNT(*)
FROM ${ctx.ref("ecom_wishlist_to_purchase")}
GROUP BY grain HAVING COUNT(*) > 1
UNION ALL
SELECT 'mkt_brand_paid_organic_cannibalization', TO_JSON_STRING(STRUCT(week_start)) AS grain, COUNT(*)
FROM ${ctx.ref("mkt_brand_paid_organic_cannibalization")}
GROUP BY grain HAVING COUNT(*) > 1`);

checkExtra("assert_extras_rates_between_0_and_1",
  "Rates of the new tables are proportions: never below 0 or above 1 (a bigger number means a broken join)",
  ctx => `
SELECT 'rpt_ga4_user_acquisition_cohort' AS model, CAST(cohort_month AS STRING) AS row_key, retention_rate AS rate
FROM ${ctx.ref("rpt_ga4_user_acquisition_cohort")}
WHERE retention_rate < 0 OR retention_rate > 1
UNION ALL
SELECT 'ecom_wishlist_to_purchase', item_id, wishlist_conversion_rate
FROM ${ctx.ref("ecom_wishlist_to_purchase")}
WHERE wishlist_conversion_rate < 0 OR wishlist_conversion_rate > 1
UNION ALL
SELECT 'ecom_regional_bestsellers', CONCAT(geo_uf, ' / ', item_category), share_in_uf
FROM ${ctx.ref("ecom_regional_bestsellers")}
WHERE share_in_uf < 0 OR share_in_uf > 1
UNION ALL
SELECT 'biz_identified_vs_anonymous_value', CAST(month_start AS STRING), identified_session_share
FROM ${ctx.ref("biz_identified_vs_anonymous_value")}
WHERE identified_session_share < 0 OR identified_session_share > 1`);

checkExtra("assert_extras_cannibalization_not_above_launch",
  "Incremental + cannibalized revenue of a launch is exactly its revenue (the split cannot create money)",
  ctx => `
SELECT item_id, launch_revenue, incremental_revenue, cannibalized_revenue
FROM ${ctx.ref("ecom_launch_cannibalization")}
WHERE ABS(incremental_revenue + cannibalized_revenue - launch_revenue) > 0.01`);
