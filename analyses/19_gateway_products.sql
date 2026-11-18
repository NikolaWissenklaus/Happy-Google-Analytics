-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- gateway products: which product, bought in the FIRST order, creates customers that come back?
-- and the opposite, "one and done" products: their buyers never return (bad experience, wrong
-- expectation, or a product people buy once in life). Use it to choose what to advertise for
-- acquisition: the hero of the ads should be the product that creates loyal customers, not the
-- one with the cheapest CPA.

WITH first_orders AS (
  SELECT user_key, transaction_id, transaction_ts
  FROM (
    SELECT user_key, transaction_id, transaction_ts,
      ROW_NUMBER() OVER (PARTITION BY user_key ORDER BY transaction_ts) AS rn
    FROM `your-gcp-project.ga4_core.fct_transactions`
    WHERE is_valid_for_revenue
  )
  WHERE rn = 1
    -- old enough to have had 180 days to come back
    AND DATE(transaction_ts) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 545 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
),
first_items AS (
  SELECT DISTINCT f.user_key, f.transaction_ts, i.item_id, i.item_name, i.item_category
  FROM first_orders AS f
  JOIN `your-gcp-project.ga4_core.fct_transaction_items` AS i USING (transaction_id)
),
future AS (
  SELECT
    f.user_key,
    COUNTIF(t.transaction_ts > f.transaction_ts AND TIMESTAMP_DIFF(t.transaction_ts, f.transaction_ts, DAY) <= 180) AS repeat_orders_180d,
    SUM(IF(t.transaction_ts > f.transaction_ts AND TIMESTAMP_DIFF(t.transaction_ts, f.transaction_ts, DAY) <= 180, t.revenue, 0)) AS repeat_revenue_180d
  FROM first_orders AS f
  LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key
    AND t.is_valid_for_revenue
  GROUP BY f.user_key
),
by_item AS (
  SELECT
    i.item_id,
    ANY_VALUE(i.item_name) AS item_name,
    ANY_VALUE(i.item_category) AS item_category,
    COUNT(*) AS first_buyers,
    SAFE_DIVIDE(COUNTIF(f.repeat_orders_180d > 0), COUNT(*)) AS repeat_rate_180d,
    AVG(f.repeat_revenue_180d) AS repeat_revenue_per_buyer_180d
  FROM first_items AS i
  JOIN future AS f USING (user_key)
  GROUP BY i.item_id
  HAVING COUNT(*) >= 30
),
site AS (
  SELECT SAFE_DIVIDE(COUNTIF(repeat_orders_180d > 0), COUNT(*)) AS site_repeat_rate FROM future
)
SELECT
  b.*,
  s.site_repeat_rate,
  SAFE_DIVIDE(b.repeat_rate_180d, s.site_repeat_rate) AS loyalty_index,
  `your-gcp-project.ga4_udf.wilson_interval`(ROUND(b.repeat_rate_180d * b.first_buyers), b.first_buyers, 1.96) AS repeat_rate_interval,
  CASE
    WHEN SAFE_DIVIDE(b.repeat_rate_180d, s.site_repeat_rate) >= 1.3 THEN 'gateway_product'
    WHEN SAFE_DIVIDE(b.repeat_rate_180d, s.site_repeat_rate) <= 0.7 THEN 'one_and_done'
    ELSE 'neutral'
  END AS role
FROM by_item AS b
CROSS JOIN site AS s
ORDER BY loyalty_index DESC;

-- same question by category of the first order (more volume, more stable)
WITH first_orders AS (
  SELECT user_key, transaction_id, transaction_ts
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND is_first_purchase
    AND transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 545 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
),
main_category AS (
  SELECT transaction_id, ARRAY_AGG(item_category ORDER BY item_revenue DESC LIMIT 1)[OFFSET(0)] AS first_category
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  GROUP BY transaction_id
)
SELECT
  COALESCE(m.first_category, '(not set)') AS first_category,
  COUNT(DISTINCT f.user_key) AS first_buyers,
  SAFE_DIVIDE(COUNT(DISTINCT IF(t.transaction_ts > f.transaction_ts AND TIMESTAMP_DIFF(t.transaction_ts, f.transaction_ts, DAY) <= 180, f.user_key, NULL)),
    COUNT(DISTINCT f.user_key)) AS repeat_rate_180d
FROM first_orders AS f
LEFT JOIN main_category AS m USING (transaction_id)
LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
  ON t.user_key = f.user_key AND t.is_valid_for_revenue
GROUP BY 1
HAVING COUNT(DISTINCT f.user_key) >= 50
ORDER BY repeat_rate_180d DESC;
