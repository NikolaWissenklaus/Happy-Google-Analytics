-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the B2B customers hiding inside the B2C store
-- resellers, small shops, offices, salons, restaurants: they buy many units of the same product,
-- on business days, from desktop, at business hours, again and again. They are usually the best
-- customers of the store and are treated like anybody else. Find them, give them a wholesale
-- table, a seller and a payment term.

WITH lines AS (
  SELECT user_key, transaction_id, transaction_ts, item_id, quantity, item_revenue
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
),
orders AS (
  SELECT
    t.user_key,
    t.transaction_id,
    t.revenue,
    t.device_category,
    EXTRACT(DAYOFWEEK FROM DATETIME(t.transaction_ts, 'America/Sao_Paulo')) BETWEEN 2 AND 6 AS is_weekday,
    EXTRACT(HOUR FROM DATETIME(t.transaction_ts, 'America/Sao_Paulo')) BETWEEN 8 AND 18 AS is_business_hours,
    LOWER(COALESCE(t.payment_type, '')) AS payment_type
  FROM `your-gcp-project.ga4_core.fct_transactions` AS t
  WHERE t.is_valid_for_revenue AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
),
per_customer AS (
  SELECT
    o.user_key,
    COUNT(DISTINCT o.transaction_id) AS orders,
    SUM(o.revenue) AS revenue,
    AVG(o.revenue) AS aov,
    SAFE_DIVIDE(COUNTIF(o.is_weekday AND o.is_business_hours), COUNT(*)) AS business_time_share,
    SAFE_DIVIDE(COUNTIF(o.device_category = 'desktop'), COUNT(*)) AS desktop_share,
    SAFE_DIVIDE(COUNTIF(o.payment_type LIKE '%boleto%' OR o.payment_type LIKE '%faturado%'), COUNT(*)) AS boleto_share
  FROM orders AS o
  GROUP BY o.user_key
),
quantities AS (
  SELECT user_key,
    MAX(quantity) AS max_units_one_line,
    AVG(quantity) AS avg_units_per_line,
    COUNTIF(quantity >= 5) AS lines_with_5_plus_units
  FROM lines
  GROUP BY user_key
)
SELECT
  c.*,
  q.max_units_one_line,
  q.avg_units_per_line,
  q.lines_with_5_plus_units,
  u.user_id,
  u.first_uf,
  -- simple additive score, tune with the customers you already KNOW are B2B
  IF(q.avg_units_per_line >= 3, 30, 0)
    + IF(q.lines_with_5_plus_units >= 2, 25, 0)
    + IF(c.orders >= 4, 15, 0)
    + IF(c.business_time_share >= 0.8, 15, 0)
    + IF(c.desktop_share >= 0.7, 10, 0)
    + IF(c.boleto_share >= 0.5, 5, 0) AS b2b_score
FROM per_customer AS c
JOIN quantities AS q USING (user_key)
LEFT JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
WHERE c.orders >= 2
ORDER BY b2b_score DESC, revenue DESC
LIMIT 300;

-- how big is it? share of the revenue of the customers with b2b_score >= 60: run the query
-- above as a CTE and SUM(revenue) by (b2b_score >= 60)
