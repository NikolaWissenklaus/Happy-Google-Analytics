-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- training: 12 exercises on the core tables, from the first week to the senior level, each one with
-- the question, a hint and a solution. Try before reading the solution. They only use ga4_core and ga4_udf.

-- ============================================================ junior

-- 1) how many sessions and orders did each device have yesterday?
--    hint: fct_sessions, GROUP BY, NOT is_bot_suspect
SELECT device_category, COUNT(*) AS sessions, SUM(transactions) AS orders
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AND NOT is_bot_suspect
GROUP BY 1;

-- 2) the 10 landing pages with more sessions in 28 days and their conversion
--    hint: SAFE_DIVIDE never divides by zero
SELECT landing_page_path, COUNT(*) AS sessions, SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY) AND NOT is_bot_suspect
GROUP BY 1
ORDER BY sessions DESC
LIMIT 10;

-- 3) the official revenue of last month (the right table and the right flag)
--    hint: fct_transactions + is_valid_for_revenue
SELECT SUM(revenue) AS revenue, COUNT(*) AS orders
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  AND transaction_date < DATE_TRUNC(CURRENT_DATE(), MONTH);

-- ============================================================ mid

-- 4) revenue of each day and its 7 day moving average
--    hint: window function AVG() OVER (ORDER BY ... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
SELECT transaction_date, SUM(revenue) AS revenue,
  AVG(SUM(revenue)) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS revenue_7d_avg
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
GROUP BY 1
ORDER BY 1;

-- 5) the share of the revenue of each channel inside each week
--    hint: SUM(x) / SUM(SUM(x)) OVER (PARTITION BY week)
SELECT session_week, session_default_channel_group, SUM(revenue) AS revenue,
  SAFE_DIVIDE(SUM(revenue), SUM(SUM(revenue)) OVER (PARTITION BY session_week)) AS share_of_week
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 56 DAY) AND NOT is_bot_suspect
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- 6) days between the first and the second purchase of each customer (median per first channel)
--    hint: order_number and days_since_previous_order are already in fct_transactions
SELECT session_default_channel_group AS channel_of_2nd_order, COUNT(*) AS customers,
  APPROX_QUANTILES(days_since_previous_order, 2)[OFFSET(1)] AS median_days
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND order_number = 2
GROUP BY 1
ORDER BY customers DESC;

-- 7) the funnel of yesterday: sessions -> product view -> cart -> checkout -> purchase (closed)
--    hint: COUNTIF with the flags of fct_sessions, each step AND the ones before
SELECT
  COUNT(*) AS sessions,
  COUNTIF(has_view_item) AS viewed,
  COUNTIF(has_view_item AND has_add_to_cart) AS carted,
  COUNTIF(has_view_item AND has_add_to_cart AND has_begin_checkout) AS checkout,
  COUNTIF(has_view_item AND has_add_to_cart AND has_begin_checkout AND has_purchase) AS bought
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AND NOT is_bot_suspect;

-- ============================================================ senior

-- 8) monthly retention of the customers: of the customers of month M, how many bought again in M+1
--    hint: self join on user_key with month + 1
WITH monthly AS (
  SELECT DISTINCT user_key, DATE_TRUNC(transaction_date, MONTH) AS month
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 13 MONTH)
)
SELECT a.month, COUNT(*) AS customers, COUNT(b.user_key) AS bought_next_month, SAFE_DIVIDE(COUNT(b.user_key), COUNT(*)) AS retention
FROM monthly AS a
LEFT JOIN monthly AS b ON b.user_key = a.user_key AND b.month = DATE_ADD(a.month, INTERVAL 1 MONTH)
GROUP BY 1
ORDER BY 1;

-- 9) is the conversion of mobile this week really different from last week? (z test with the UDF)
WITH weeks AS (
  SELECT
    COUNTIF(session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) AS n_this, COUNTIF(session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND has_purchase) AS c_this,
    COUNTIF(session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) AS n_last, COUNTIF(session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND has_purchase) AS c_last
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND session_date < CURRENT_DATE()
    AND device_category = 'mobile' AND NOT is_bot_suspect
)
SELECT `your-gcp-project.ga4_udf.z_test_proportions`(c_last, n_last, c_this, n_this) AS z_test FROM weeks;

-- 10) the landing pages ranked by the LOWER bound of the conversion (small pages stop winning by luck)
SELECT landing_page_path, COUNT(*) AS sessions, SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)) AS conversion,
  `your-gcp-project.ga4_udf.wilson_interval`(COUNTIF(has_purchase), COUNT(*), 1.96).low AS conversion_low
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY) AND NOT is_bot_suspect
GROUP BY 1
HAVING COUNT(*) >= 30
ORDER BY conversion_low DESC
LIMIT 20;

-- ============================================================ specialist

-- 11) the sessions a "user" really is: cookies per logged person per browser (identity inflation)
SELECT s.device_browser, COUNT(DISTINCT s.user_key) AS people, COUNT(DISTINCT s.user_pseudo_id) AS cookies,
  SAFE_DIVIDE(COUNT(DISTINCT s.user_pseudo_id), COUNT(DISTINCT s.user_key)) AS cookies_per_person
FROM `your-gcp-project.ga4_core.fct_sessions` AS s
WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND s.is_identified_user AND NOT s.is_bot_suspect
GROUP BY 1
HAVING COUNT(DISTINCT s.user_key) >= 50
ORDER BY cookies_per_person DESC;

-- 12) the change points of the daily conversion with the PELT UDF, by hand (ds_kpi_regimes does it for every KPI)
WITH daily AS (
  SELECT session_date, SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)) AS conversion
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND session_date < CURRENT_DATE() AND NOT is_bot_suspect
  GROUP BY 1
),
series AS (
  SELECT ARRAY_AGG(conversion ORDER BY session_date) AS values_, ARRAY_AGG(session_date ORDER BY session_date) AS dates
  FROM daily
)
SELECT dates[OFFSET(CAST(r.start_index AS INT64))] AS regime_start, dates[OFFSET(CAST(r.end_index AS INT64))] AS regime_end, r.mean AS conversion
FROM series, UNNEST(`your-gcp-project.ga4_udf.pelt_changepoints`(values_, 3, 14)) AS r
ORDER BY regime_start;
