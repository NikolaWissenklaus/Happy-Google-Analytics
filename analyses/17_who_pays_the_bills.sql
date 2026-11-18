-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- who pays the bills: new or returning customers?
-- every board asks "are we growing by acquisition or by loyalty?". the answer changes where the
-- money goes: a store living of new customers needs media, one living of returning customers
-- needs CRM, assortment and service. Run monthly.

-- 1) revenue split by order number (1st order, 2nd, 3rd+) per month
SELECT
  DATE_TRUNC(transaction_date, MONTH) AS month,
  COUNT(*) AS orders,
  SUM(revenue) AS revenue,
  SAFE_DIVIDE(SUM(IF(order_number = 1, revenue, 0)), SUM(revenue)) AS share_first_orders,
  SAFE_DIVIDE(SUM(IF(order_number = 2, revenue, 0)), SUM(revenue)) AS share_second_orders,
  SAFE_DIVIDE(SUM(IF(order_number >= 3, revenue, 0)), SUM(revenue)) AS share_loyal_orders,
  SAFE_DIVIDE(SUM(IF(order_number = 1, revenue, 0)), COUNTIF(order_number = 1)) AS aov_first_order,
  SAFE_DIVIDE(SUM(IF(order_number > 1, revenue, 0)), COUNTIF(order_number > 1)) AS aov_repeat_order
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 13 MONTH)
GROUP BY month
ORDER BY month;

-- 2) the "base" of the revenue: how much of this year's revenue comes from customers acquired in
-- previous years (the older the base, the more the business is an asset and less a media machine)
SELECT
  EXTRACT(YEAR FROM u.first_purchase_date) AS acquisition_year,
  COUNT(DISTINCT t.user_key) AS customers_buying_this_year,
  SUM(t.revenue) AS revenue_this_year,
  SAFE_DIVIDE(SUM(t.revenue), SUM(SUM(t.revenue)) OVER ()) AS share_of_revenue
FROM `your-gcp-project.ga4_core.fct_transactions` AS t
JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
WHERE t.is_valid_for_revenue
  AND t.transaction_date >= DATE_TRUNC(CURRENT_DATE(), YEAR)
GROUP BY acquisition_year
ORDER BY acquisition_year;

-- 3) repeat rate of each monthly cohort of first buyers after 30 / 90 / 180 days
-- (the curve that tells if loyalty is getting better or worse over time)
WITH first_orders AS (
  SELECT user_key, MIN(transaction_ts) AS first_ts, DATE_TRUNC(MIN(transaction_date), MONTH) AS cohort_month
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue
  GROUP BY user_key
),
repeats AS (
  SELECT
    f.cohort_month,
    f.user_key,
    MIN(TIMESTAMP_DIFF(t.transaction_ts, f.first_ts, DAY)) AS days_to_second
  FROM first_orders AS f
  LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key
    AND t.is_valid_for_revenue
    AND t.transaction_ts > f.first_ts
  GROUP BY 1, 2
)
SELECT
  cohort_month,
  COUNT(*) AS new_customers,
  SAFE_DIVIDE(COUNTIF(days_to_second <= 30), COUNT(*)) AS repeat_30d,
  SAFE_DIVIDE(COUNTIF(days_to_second <= 90), COUNT(*)) AS repeat_90d,
  SAFE_DIVIDE(COUNTIF(days_to_second <= 180), COUNT(*)) AS repeat_180d,
  -- the most recent cohorts did not have time yet
  DATE_DIFF(CURRENT_DATE(), cohort_month, DAY) < 180 AS is_immature
FROM repeats
WHERE cohort_month >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 18 MONTH)
GROUP BY cohort_month
ORDER BY cohort_month;
