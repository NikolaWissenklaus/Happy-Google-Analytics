-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- which channel brings customers that COME BACK (and not only cheap first orders)?
-- the CPA of the first order lies: a channel with a cheap CPA and customers that never return is
-- more expensive than one with a higher CPA and customers that buy 4 times a year.

-- 1) value of the customer by the channel of the FIRST order, after 90 / 180 / 365 days
WITH first_orders AS (
  SELECT
    user_key,
    transaction_ts AS first_ts,
    transaction_date AS first_date,
    revenue AS first_order_revenue,
    COALESCE(session_default_channel_group, 'Unassigned') AS acquisition_channel,
    used_coupon_first
  FROM (
    SELECT *, coupon IS NOT NULL AS used_coupon_first,
      ROW_NUMBER() OVER (PARTITION BY user_key ORDER BY transaction_ts) AS rn
    FROM `your-gcp-project.ga4_core.fct_transactions`
    WHERE is_valid_for_revenue
  )
  WHERE rn = 1
    AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
),
later AS (
  SELECT
    f.user_key,
    SUM(IF(TIMESTAMP_DIFF(t.transaction_ts, f.first_ts, DAY) <= 90, t.revenue, 0)) AS revenue_90d,
    SUM(IF(TIMESTAMP_DIFF(t.transaction_ts, f.first_ts, DAY) <= 180, t.revenue, 0)) AS revenue_180d,
    SUM(IF(TIMESTAMP_DIFF(t.transaction_ts, f.first_ts, DAY) <= 365, t.revenue, 0)) AS revenue_365d,
    COUNTIF(t.transaction_ts > f.first_ts AND TIMESTAMP_DIFF(t.transaction_ts, f.first_ts, DAY) <= 180) AS repeat_orders_180d
  FROM first_orders AS f
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key
    AND t.is_valid_for_revenue
    AND t.transaction_ts >= f.first_ts
  GROUP BY f.user_key
)
SELECT
  f.acquisition_channel,
  COUNT(*) AS new_customers,
  AVG(f.first_order_revenue) AS avg_first_order,
  SAFE_DIVIDE(COUNTIF(f.used_coupon_first), COUNT(*)) AS first_order_with_coupon,
  -- only customers old enough for each window enter the averages
  AVG(IF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), l.revenue_90d, NULL)) AS revenue_per_customer_90d,
  AVG(IF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), l.revenue_180d, NULL)) AS revenue_per_customer_180d,
  AVG(IF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY), l.revenue_365d, NULL)) AS revenue_per_customer_365d,
  SAFE_DIVIDE(
    COUNTIF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND l.repeat_orders_180d > 0),
    COUNTIF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY))
  ) AS repeat_rate_180d,
  -- how much the first order "multiplies" in a year: 2.0 = the customer buys the same again
  SAFE_DIVIDE(
    AVG(IF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY), l.revenue_365d, NULL)),
    AVG(IF(f.first_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY), f.first_order_revenue, NULL))
  ) AS ltv_multiplier_365d
FROM first_orders AS f
JOIN later AS l USING (user_key)
GROUP BY f.acquisition_channel
HAVING COUNT(*) >= 50
ORDER BY revenue_per_customer_180d DESC;

-- 2) cost per new customer by platform and month (costs of fct_ad_costs_daily vs first orders
-- whose session medium is paid). With the 180 day value above you get a real LTV / CAC
WITH costs AS (
  SELECT DATE_TRUNC(cost_date, MONTH) AS month, LOWER(source) AS source, SUM(cost) AS cost
  FROM `your-gcp-project.ga4_core.fct_ad_costs_daily`
  WHERE cost_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 12 MONTH)
  GROUP BY 1, 2
),
new_customers AS (
  SELECT DATE_TRUNC(transaction_date, MONTH) AS month, LOWER(session_source) AS source, COUNT(*) AS new_customers, SUM(revenue) AS first_order_revenue
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue
    AND is_first_purchase
    AND transaction_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 12 MONTH)
  GROUP BY 1, 2
)
SELECT
  c.month,
  c.source,
  c.cost,
  COALESCE(n.new_customers, 0) AS new_customers,
  SAFE_DIVIDE(c.cost, n.new_customers) AS cost_per_new_customer,
  SAFE_DIVIDE(n.first_order_revenue, c.cost) AS first_order_roas
FROM costs AS c
LEFT JOIN new_customers AS n USING (month, source)
ORDER BY c.month DESC, c.cost DESC;
