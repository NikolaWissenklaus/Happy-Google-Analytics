-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the history of the KPIs told as regimes, the weekday effect taken out, and the next 28 days

-- 1) every regime of every KPI: when the level changed, by how much, and what was going on
SELECT kpi, regime_number, start_date, end_date, days, mean_value, relative_change_vs_previous, is_material,
       ARRAY_TO_STRING(possible_causes, '; ') AS possible_causes
FROM `your-gcp-project.ga4_data_science.ds_kpi_regimes`
ORDER BY kpi, regime_number;

-- 2) the regimes that started recently (the level of today is new)
SELECT kpi, start_date, mean_value, previous_mean_value, relative_change_vs_previous, ARRAY_TO_STRING(possible_causes, '; ') AS around_that_day
FROM `your-gcp-project.ga4_data_science.ds_kpi_regimes`
WHERE is_new_regime
ORDER BY ABS(relative_change_vs_previous) DESC;

-- 3) the weekday effect of each KPI (1.15 = that weekday is 15% above the trend)
SELECT DISTINCT kpi, iso_weekday, weekday_index
FROM `your-gcp-project.ga4_data_science.ds_kpi_decomposition`
WHERE weekday_index IS NOT NULL
ORDER BY kpi, iso_weekday;

-- 4) the fair comparison of the last days: seasonally adjusted, and the days nothing explains
SELECT metric_date, kpi, value, trend, weekday_index, seasonally_adjusted, seasonally_adjusted_7d, residual_robust_z, is_unusual_day
FROM `your-gcp-project.ga4_data_science.ds_kpi_decomposition`
WHERE kpi = 'revenue'
  AND metric_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 21 DAY)
ORDER BY metric_date;

-- 5) the forecast of the next 28 days, with the honest error of the backtest next to it
SELECT kpi, metric_date, row_type, actual, forecast_value, low_80, high_80, low_95, high_95, holdout_mape
FROM `your-gcp-project.ga4_data_science.ds_kpi_forecast_holt_winters`
WHERE metric_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
ORDER BY kpi, metric_date;

-- 6) the month end in one line: complete days so far + the forecast of the rest of the month
SELECT
  kpi,
  SUM(IF(row_type = 'actual', actual, 0)) AS month_to_date,
  SUM(IF(row_type = 'forecast', forecast_value, 0)) AS forecast_rest_of_month,
  SUM(IF(row_type = 'actual', actual, forecast_value)) AS projected_month
FROM `your-gcp-project.ga4_data_science.ds_kpi_forecast_holt_winters`
WHERE metric_date BETWEEN DATE_TRUNC(CURRENT_DATE(), MONTH) AND LAST_DAY(CURRENT_DATE(), MONTH)
GROUP BY 1;
