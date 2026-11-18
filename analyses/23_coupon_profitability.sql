-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- are coupons buying growth or just giving away margin?
-- a coupon pays off when it brings a customer that would not come, or makes them come back.
-- it burns money when it goes to people that were going to buy anyway (returning customers,
-- people already in the checkout that googled "cupom <loja>").

-- 1) every coupon: orders, discount given, AOV, share of new customers, who already was a customer
SELECT
  coupon,
  COUNT(*) AS orders,
  SUM(revenue) AS revenue,
  AVG(revenue) AS aov,
  SAFE_DIVIDE(COUNTIF(is_first_purchase), COUNT(*)) AS share_new_customers,
  SAFE_DIVIDE(COUNTIF(NOT is_first_purchase), COUNT(*)) AS share_existing_customers,
  SAFE_DIVIDE(COUNTIF(session_default_channel_group IN ('Organic Search', 'Direct')), COUNT(*)) AS share_from_search_or_direct,
  -- discount = items + shipping - what was paid (taxes ignored, an order of magnitude)
  SUM(GREATEST(0, COALESCE(items_revenue, 0) + COALESCE(shipping_value, 0) - revenue)) AS approx_discount_given
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND coupon IS NOT NULL
  AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY coupon
HAVING COUNT(*) >= 10
ORDER BY revenue DESC;

-- 2) first order with coupon vs without: do coupon customers come back (without coupon)?
WITH first_orders AS (
  SELECT user_key, transaction_ts, coupon IS NOT NULL AS first_with_coupon, revenue
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND is_first_purchase
    AND transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 545 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
),
next_180 AS (
  SELECT
    f.user_key,
    f.first_with_coupon,
    f.revenue AS first_revenue,
    COUNTIF(t.transaction_ts > f.transaction_ts) AS repeat_orders,
    COUNTIF(t.transaction_ts > f.transaction_ts AND t.coupon IS NULL) AS repeat_orders_full_price,
    SUM(IF(t.transaction_ts > f.transaction_ts, t.revenue, 0)) AS repeat_revenue
  FROM first_orders AS f
  LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key AND t.is_valid_for_revenue
    AND t.transaction_ts <= TIMESTAMP_ADD(f.transaction_ts, INTERVAL 180 DAY)
  GROUP BY 1, 2, 3
)
SELECT
  first_with_coupon,
  COUNT(*) AS customers,
  AVG(first_revenue) AS avg_first_order,
  SAFE_DIVIDE(COUNTIF(repeat_orders > 0), COUNT(*)) AS repeat_rate_180d,
  SAFE_DIVIDE(COUNTIF(repeat_orders_full_price > 0), COUNT(*)) AS repeat_full_price_rate_180d,
  AVG(repeat_revenue) AS repeat_revenue_per_customer_180d
FROM next_180
GROUP BY first_with_coupon;

-- 3) coupon addicts: customers whose every order has a coupon (they learned to wait)
SELECT
  CASE
    WHEN coupon_share = 1 THEN 'always_coupon'
    WHEN coupon_share >= 0.5 THEN 'mostly_coupon'
    WHEN coupon_share > 0 THEN 'sometimes_coupon'
    ELSE 'never_coupon'
  END AS coupon_behaviour,
  COUNT(*) AS customers,
  AVG(orders) AS avg_orders,
  AVG(revenue) AS avg_revenue
FROM (
  SELECT user_key, COUNT(*) AS orders, SUM(revenue) AS revenue, SAFE_DIVIDE(COUNTIF(coupon IS NOT NULL), COUNT(*)) AS coupon_share
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
  GROUP BY user_key
  HAVING COUNT(*) >= 2
)
GROUP BY coupon_behaviour
ORDER BY customers DESC;

-- the coupons that leaked to coupon sites are in ga4_promotions.promo_coupon_hijacking
