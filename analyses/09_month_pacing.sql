-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- are we going to hit the target of the month? (targets in cfg_targets.js)
-- gap_vs_expected < 0 = behind the curve. required_daily_revenue = what each remaining day needs.

SELECT
  day,
  actual_revenue,
  actual_cumulative_revenue,
  expected_cumulative_revenue,
  gap_vs_expected,
  required_daily_revenue,
  target_revenue
FROM `your-gcp-project.ga4_business.biz_targets_pacing`
WHERE NOT is_future_day
ORDER BY day DESC
LIMIT 31;

-- with enable_bqml, the forecast of the next days (ARIMA_PLUS with brazilian holidays)
-- SELECT * FROM `your-gcp-project.ga4_data_science.ds_kpi_forecast` WHERE metric = 'revenue' ORDER BY metric_date;
