-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- when should the "come back" message go out?
-- the second purchase is the hardest one (after it, the chance of a third one jumps). The
-- distribution of the days between the 1st and the 2nd order tells WHEN to send the reminder:
-- before the p25 is too early (annoying), after the p75 is too late (they already forgot you).

-- 1) days between 1st and 2nd order: percentiles, overall and per category of the first order
WITH ordered AS (
  SELECT user_key, transaction_id, transaction_ts,
    ROW_NUMBER() OVER (PARTITION BY user_key ORDER BY transaction_ts) AS n
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 730 DAY)
),
pairs AS (
  SELECT a.user_key, a.transaction_id AS first_order, TIMESTAMP_DIFF(b.transaction_ts, a.transaction_ts, DAY) AS days_to_second
  FROM ordered AS a
  JOIN ordered AS b ON b.user_key = a.user_key AND b.n = 2
  WHERE a.n = 1
),
first_category AS (
  SELECT transaction_id, ARRAY_AGG(item_category ORDER BY item_revenue DESC LIMIT 1)[OFFSET(0)] AS category
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  GROUP BY transaction_id
)
SELECT
  COALESCE(c.category, '(all)') AS first_order_category,
  COUNT(*) AS customers_with_second_order,
  APPROX_QUANTILES(p.days_to_second, 100)[OFFSET(25)] AS p25_days,
  APPROX_QUANTILES(p.days_to_second, 100)[OFFSET(50)] AS median_days,
  APPROX_QUANTILES(p.days_to_second, 100)[OFFSET(75)] AS p75_days,
  -- suggested window for the reminder flow
  CONCAT('day ', CAST(APPROX_QUANTILES(p.days_to_second, 100)[OFFSET(25)] AS STRING), ' to day ',
         CAST(APPROX_QUANTILES(p.days_to_second, 100)[OFFSET(60)] AS STRING)) AS reminder_window
FROM pairs AS p
LEFT JOIN first_category AS c ON c.transaction_id = p.first_order
GROUP BY ROLLUP (c.category)
HAVING COUNT(*) >= 30
ORDER BY customers_with_second_order DESC;

-- 2) the hazard of the second purchase by week since the first: after which week does the chance
-- almost vanish? (that is the deadline of the welcome flow)
WITH first_orders AS (
  SELECT user_key, MIN(transaction_ts) AS first_ts
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue
  GROUP BY user_key
  HAVING DATE(MIN(transaction_ts)) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 545 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
),
second AS (
  SELECT f.user_key, MIN(DIV(TIMESTAMP_DIFF(t.transaction_ts, f.first_ts, DAY), 7)) AS week_of_second
  FROM first_orders AS f
  LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key AND t.is_valid_for_revenue AND t.transaction_ts > f.first_ts
  GROUP BY f.user_key
),
weeks AS (SELECT w FROM UNNEST(GENERATE_ARRAY(0, 25)) AS w)
SELECT
  w AS week_since_first_order,
  COUNTIF(week_of_second IS NULL OR week_of_second >= w) AS still_waiting,
  COUNTIF(week_of_second = w) AS second_orders_this_week,
  SAFE_DIVIDE(COUNTIF(week_of_second = w), COUNTIF(week_of_second IS NULL OR week_of_second >= w)) AS hazard
FROM weeks CROSS JOIN second
GROUP BY w
ORDER BY w;
