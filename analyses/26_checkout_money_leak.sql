-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- where does the money leak out of the checkout, in R$ and not in %?
-- a 70% cart abandonment means nothing to a director. "R$ 380 mil stopped at the shipping step
-- last month, 60% of it on mobile, mostly with Sedex" does.

-- 1) value that stopped at each step (last step reached in the session), last 30 days
SELECT
  CASE
    WHEN has_purchase THEN '5_purchased'
    WHEN has_add_payment_info THEN '4_stopped_at_payment'
    WHEN has_add_shipping_info THEN '3_stopped_at_shipping'
    WHEN has_begin_checkout THEN '2_stopped_at_checkout_start'
    WHEN has_add_to_cart THEN '1_stopped_at_cart'
  END AS last_step,
  device_category,
  COUNT(*) AS sessions,
  SUM(GREATEST(COALESCE(checkout_value, 0), COALESCE(cart_value, 0))) AS value_at_this_step,
  AVG(GREATEST(COALESCE(checkout_value, 0), COALESCE(cart_value, 0))) AS avg_value
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND has_add_to_cart
  AND NOT is_bot_suspect
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2) at the shipping and payment steps: which shipping tier / payment type was chosen last
-- in the sessions that died there (Sedex too expensive? boleto scaring people?)
SELECT
  IF(has_add_payment_info, 'stopped_at_payment', 'stopped_at_shipping') AS stopped_at,
  COALESCE(last_shipping_tier, '(not set)') AS shipping_tier,
  COALESCE(last_payment_type, '(not set)') AS payment_type,
  COUNT(*) AS sessions,
  SUM(checkout_value) AS value_lost,
  SAFE_DIVIDE(COUNTIF(has_payment_retries), COUNT(*)) AS share_with_payment_retries
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND has_add_shipping_info
  AND NOT has_purchase
  AND NOT is_bot_suspect
GROUP BY 1, 2, 3
HAVING COUNT(*) >= 20
ORDER BY value_lost DESC;

-- 3) how much of the leak comes back by itself (same person buys within 7 days)?
-- the part that never comes back is the real target of the CRM flows
WITH abandoned AS (
  SELECT session_key, user_key, session_end_ts, checkout_value
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 37 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    AND is_checkout_abandoned AND NOT is_bot_suspect
)
SELECT
  COUNT(*) AS abandoned_checkouts,
  SUM(a.checkout_value) AS value_abandoned,
  COUNTIF(r.user_key IS NOT NULL) AS came_back_and_bought,
  SAFE_DIVIDE(COUNTIF(r.user_key IS NOT NULL), COUNT(*)) AS self_recovery_rate,
  SUM(IF(r.user_key IS NULL, a.checkout_value, 0)) AS value_never_recovered
FROM abandoned AS a
LEFT JOIN (
  SELECT DISTINCT a2.session_key, a2.user_key
  FROM abandoned AS a2
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = a2.user_key
    AND t.transaction_ts > a2.session_end_ts
    AND t.transaction_ts <= TIMESTAMP_ADD(a2.session_end_ts, INTERVAL 7 DAY)
    AND t.is_valid_for_revenue
) AS r USING (session_key);

-- items people give up on in the cart, and regret (frontier): ecom_abandoned_cart_items, ecom_cart_indecision
