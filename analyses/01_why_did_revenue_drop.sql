-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- why did revenue drop?
-- 1) is it real or tracking? 2) which lever (traffic, conversion, ticket)? 3) where exactly?

-- 1) trust first: if the data trust index is low, the "drop" may be the tracking
SELECT check_date, data_trust_index, failing_checks
FROM `your-gcp-project.ga4_data_quality.dq_data_trust_index_daily`
ORDER BY check_date DESC
LIMIT 7;

-- 2) the bridge: how much of the change comes from sessions, conversion and AOV (LMDI, sums exactly)
SELECT comparison, month_start, revenue_before, revenue_after, revenue_change_pct,
       sessions_effect, conversion_effect, aov_effect, main_driver
FROM `your-gcp-project.ga4_business.biz_revenue_bridge`
ORDER BY month_start DESC;

-- 3) where: the alerts of the last days already come with the main cause
SELECT metric_date, metric, severity, deviation_pct, cause_dimension, cause_value, cause_share, message
FROM `your-gcp-project.ga4_anomaly.anom_alert_feed`
WHERE metric IN ('revenue', 'purchases', 'conversion_rate')
ORDER BY metric_date DESC, severity DESC;

-- and every dimension value that explains the change, not only the main one
SELECT *
FROM `your-gcp-project.ga4_anomaly.anom_root_cause`
WHERE metric = 'revenue'
ORDER BY alert_date DESC
LIMIT 50;
