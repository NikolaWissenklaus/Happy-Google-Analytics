-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- what did the best customers do in the BEGINNING that the others did not?
-- if the top 10% customers mostly came through channel X, bought category Y first, or paid with
-- card in the first order, you can find the next VIPs on their first day (and bid more for them).

WITH customers AS (
  SELECT user_key, lifetime_revenue, transactions, first_purchase_date,
    NTILE(10) OVER (ORDER BY lifetime_revenue) AS value_decile
  FROM `your-gcp-project.ga4_core.dim_users`
  WHERE is_customer
    -- one year of history at least, so the value is comparable
    AND first_purchase_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
),
first_orders AS (
  SELECT * EXCEPT (rn)
  FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY t.user_key ORDER BY t.transaction_ts) AS rn
    FROM `your-gcp-project.ga4_core.fct_transactions` AS t
    WHERE t.is_valid_for_revenue
  )
  WHERE rn = 1
),
first_category AS (
  SELECT transaction_id, ARRAY_AGG(item_category ORDER BY item_revenue DESC LIMIT 1)[OFFSET(0)] AS category
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  GROUP BY transaction_id
),
base AS (
  SELECT
    IF(c.value_decile = 10, 'top_10pct', 'others') AS segment,
    f.session_default_channel_group AS first_channel,
    f.device_category AS first_device,
    COALESCE(LOWER(f.payment_type), '(not set)') AS first_payment,
    f.coupon IS NOT NULL AS first_with_coupon,
    fc.category AS first_category,
    f.revenue AS first_order_value,
    f.items_count AS first_order_lines,
    f.session_number AS sessions_before_first_order
  FROM customers AS c
  JOIN first_orders AS f USING (user_key)
  LEFT JOIN first_category AS fc USING (transaction_id)
)
-- each dimension value: share among the top 10% vs among the others. index > 150 = VIP signal
SELECT dimension, value,
  SAFE_DIVIDE(COUNTIF(segment = 'top_10pct'), SUM(COUNTIF(segment = 'top_10pct')) OVER (PARTITION BY dimension)) AS share_in_top,
  SAFE_DIVIDE(COUNTIF(segment = 'others'), SUM(COUNTIF(segment = 'others')) OVER (PARTITION BY dimension)) AS share_in_others,
  100 * SAFE_DIVIDE(
    SAFE_DIVIDE(COUNTIF(segment = 'top_10pct'), SUM(COUNTIF(segment = 'top_10pct')) OVER (PARTITION BY dimension)),
    SAFE_DIVIDE(COUNTIF(segment = 'others'), SUM(COUNTIF(segment = 'others')) OVER (PARTITION BY dimension))
  ) AS vip_index,
  COUNT(*) AS customers
FROM base
CROSS JOIN UNNEST([
  STRUCT('first_channel' AS dimension, first_channel AS value),
  STRUCT('first_device', first_device),
  STRUCT('first_payment', first_payment),
  STRUCT('first_with_coupon', CAST(first_with_coupon AS STRING)),
  STRUCT('first_category', first_category),
  STRUCT('first_order_value_band', CASE WHEN first_order_value < 100 THEN '0_100' WHEN first_order_value < 250 THEN '100_250'
                                        WHEN first_order_value < 500 THEN '250_500' ELSE '500_plus' END),
  STRUCT('first_order_lines', CAST(LEAST(first_order_lines, 4) AS STRING)),
  STRUCT('sessions_before_first_order', CAST(LEAST(sessions_before_first_order, 6) AS STRING))
])
WHERE value IS NOT NULL
GROUP BY dimension, value
HAVING COUNT(*) >= 30
ORDER BY dimension, vip_index DESC;
