-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- is the free shipping threshold in the right place?
-- too low: you pay the freight of orders that would happen anyway. too high: people give up.
-- the right one sits a bit above the natural order value and pulls people up to it.
-- set the current threshold below (R$ 199 in the example).

DECLARE threshold FLOAT64 DEFAULT 199;

-- 1) orders around the threshold in R$ 10 bands: the bunching right above it is the effect
SELECT
  CAST(FLOOR((revenue - threshold) / 10) * 10 AS INT64) AS distance_to_threshold,
  COUNT(*) AS orders,
  AVG(shipping_value) AS avg_shipping_paid,
  AVG(items_count) AS avg_lines
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  AND revenue BETWEEN threshold - 100 AND threshold + 100
GROUP BY 1
ORDER BY 1;

-- 2) how much freight the store is subsidising: orders above the threshold without paying
-- shipping, and how many of them were "natural" (would be there with any threshold)
SELECT
  COUNTIF(revenue >= threshold AND COALESCE(shipping_value, 0) = 0) AS free_shipping_orders,
  COUNTIF(revenue >= threshold + 100 AND COALESCE(shipping_value, 0) = 0) AS free_shipping_orders_far_above,
  COUNTIF(revenue BETWEEN threshold AND threshold + 30) AS orders_just_above,
  COUNTIF(revenue BETWEEN threshold - 30 AND threshold) AS orders_just_below,
  -- ratio > 1.5 = the threshold is pulling orders up (good). close to 1 = nobody sees it
  SAFE_DIVIDE(COUNTIF(revenue BETWEEN threshold AND threshold + 30), COUNTIF(revenue BETWEEN threshold - 30 AND threshold)) AS pull_ratio,
  APPROX_QUANTILES(revenue, 100)[OFFSET(50)] AS median_order_value,
  APPROX_QUANTILES(revenue, 100)[OFFSET(60)] AS p60_order_value
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY);

-- 3) the carts that died just below the threshold (money people almost spent)
SELECT
  CAST(FLOOR((cart_value - threshold) / 10) * 10 AS INT64) AS distance_to_threshold,
  COUNT(*) AS abandoned_carts,
  SUM(cart_value) AS value_left
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND is_cart_abandoned
  AND cart_value BETWEEN threshold - 60 AND threshold
  AND NOT is_bot_suspect
GROUP BY 1
ORDER BY 1;

-- 4) what people add to cross the line (frontier model): the shelf for "faltam R$ X para o frete gratis"
SELECT threshold, threshold_source, item_name, median_price, filler_adds, filler_share_of_item_adds,
       avg_gap_closed, avg_overshoot, filler_session_conversion
FROM `your-gcp-project.ga4_ecommerce.ecom_cart_filler_items`
ORDER BY threshold, filler_adds DESC;

-- 5) freight as a killer, by state (labs model)
SELECT *
FROM `your-gcp-project.ga4_ecommerce.ecom_freight_shock`
LIMIT 100;
