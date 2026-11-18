-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- which channels, products and customers give the money back?
-- a channel with a great ROAS and 25% of refunds is a mediocre channel. Media and assortment
-- decisions should run on NET revenue. Orders at least 30 days old (refunds take time).

-- 1) gross vs net revenue per channel
SELECT
  session_default_channel_group AS channel,
  COUNT(*) AS orders,
  SUM(revenue) AS gross_revenue,
  SUM(net_revenue) AS net_revenue,
  SAFE_DIVIDE(SUM(refunded_value), SUM(revenue)) AS refund_rate_value,
  SAFE_DIVIDE(COUNTIF(refunded_value > 0), COUNT(*)) AS orders_with_refund,
  SAFE_DIVIDE(COUNTIF(has_full_refund), COUNT(*)) AS full_refund_rate
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 210 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY 1
ORDER BY refund_rate_value DESC;

-- 2) products refunded the most (item level refund events) against what they sold
WITH sold AS (
  SELECT item_id, ANY_VALUE(item_name) AS item_name, ANY_VALUE(item_category) AS item_category,
         SUM(quantity) AS units_sold, SUM(item_revenue) AS revenue
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue
    AND transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 210 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY item_id
),
refunded AS (
  SELECT item_id, SUM(COALESCE(quantity, 1)) AS units_refunded, SUM(item_value) AS value_refunded
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_name = 'refund' AND event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 210 DAY)
  GROUP BY item_id
)
SELECT s.*, COALESCE(r.units_refunded, 0) AS units_refunded, COALESCE(r.value_refunded, 0) AS value_refunded,
       SAFE_DIVIDE(r.units_refunded, s.units_sold) AS unit_refund_rate
FROM sold AS s
LEFT JOIN refunded AS r USING (item_id)
WHERE s.units_sold >= 20
ORDER BY unit_refund_rate DESC
LIMIT 100;

-- 3) serial returners: customers with many orders refunded (policy, fraud or a fit problem)
SELECT
  user_key,
  COUNT(*) AS orders,
  COUNTIF(refunded_value > 0) AS refunded_orders,
  SUM(revenue) AS gross_revenue,
  SUM(net_revenue) AS net_revenue
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
GROUP BY user_key
HAVING COUNT(*) >= 3 AND SAFE_DIVIDE(COUNTIF(refunded_value > 0), COUNT(*)) >= 0.5
ORDER BY refunded_orders DESC
LIMIT 100;

-- 4) does the coupon or the payment method change the refund rate?
SELECT
  coupon IS NOT NULL AS used_coupon,
  COALESCE(LOWER(payment_type), '(not set)') AS payment_type,
  COUNT(*) AS orders,
  SAFE_DIVIDE(SUM(refunded_value), SUM(revenue)) AS refund_rate_value
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 210 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY 1, 2
HAVING COUNT(*) >= 50
ORDER BY refund_rate_value DESC;
