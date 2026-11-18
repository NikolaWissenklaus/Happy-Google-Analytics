-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- "Email has the best revenue per session" ... with intervals that do not assume a bell, and the
-- dimensions that really explain the purchase

-- 1) every channel against the site, revenue per session with the bootstrap interval of the difference
SELECT channel, sessions, estimate, ci_low, ci_high, diff_vs_site_ci_low, diff_vs_site_ci_high, is_different_from_site,
       normal_ci_low, normal_ci_high, bootstrap_to_normal_width
FROM `your-gcp-project.ga4_data_science.ds_bootstrap_channel_metrics`
WHERE metric = 'revenue_per_session'
ORDER BY estimate DESC;

-- 2) where the normal interval lies the most (skewed metrics, few big orders)
SELECT channel, metric, bootstrap_to_normal_width
FROM `your-gcp-project.ga4_data_science.ds_bootstrap_channel_metrics`
WHERE bootstrap_to_normal_width IS NOT NULL
ORDER BY ABS(LN(bootstrap_to_normal_width)) DESC
LIMIT 10;

-- 3) a bootstrap of your own metric in plain SQL (here: AOV of mobile, 200 replicates, sessions hashed in 500 buckets)
WITH buckets AS (
  SELECT ABS(MOD(FARM_FINGERPRINT(session_key), 500)) AS bucket, SUM(revenue) AS revenue, SUM(transactions) AS orders
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY) AND device_category = 'mobile' AND NOT is_bot_suspect
  GROUP BY 1
),
replicates AS (
  SELECT r, SAFE_DIVIDE(SUM(b.revenue * `your-gcp-project.ga4_udf.poisson_bootstrap_weight`(CAST(b.bucket AS STRING), r)),
                        SUM(b.orders * `your-gcp-project.ga4_udf.poisson_bootstrap_weight`(CAST(b.bucket AS STRING), r))) AS aov
  FROM buckets AS b, UNNEST(GENERATE_ARRAY(1, 200)) AS r
  GROUP BY 1
)
SELECT APPROX_QUANTILES(aov, 40)[OFFSET(1)] AS aov_low_95, APPROX_QUANTILES(aov, 40)[OFFSET(20)] AS aov_median, APPROX_QUANTILES(aov, 40)[OFFSET(39)] AS aov_high_95
FROM replicates;

-- 4) which dimension explains the purchase the most (use the top ones to segment the dashboards)
SELECT DISTINCT dimension_rank, dimension, dimension_kind, theils_u, cramers_v, chi_square_p_value, values_count
FROM `your-gcp-project.ga4_data_science.ds_conversion_drivers_information`
ORDER BY dimension_rank;

-- 5) inside the top dimensions: the values that pull the conversion up and down
SELECT dimension, value, sessions, conversion_rate, conversion_wilson_low, lift, share_of_information
FROM `your-gcp-project.ga4_data_science.ds_conversion_drivers_information`
WHERE dimension_rank <= 3
ORDER BY dimension_rank, lift DESC;
