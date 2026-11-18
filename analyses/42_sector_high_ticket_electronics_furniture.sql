-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: electronics, appliances, furniture, mattresses, bikes, jewellery (high ticket, long decision)
-- nobody buys a R$ 4.000 sofa on the first visit. The questions are: how long is the decision,
-- how many visits, through which channels, and how many people go to the competitor in the middle.
-- Set the ticket that counts as "high" below.

DECLARE high_ticket FLOAT64 DEFAULT 1500;

-- 1) the decision journey of high ticket orders vs the others: days, sessions, channels, devices
WITH orders AS (
  SELECT transaction_id, user_key, transaction_ts, revenue, revenue >= high_ticket AS is_high_ticket
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
),
journeys AS (
  SELECT
    o.transaction_id,
    o.is_high_ticket,
    COUNT(s.session_key) AS sessions_before,
    MAX(TIMESTAMP_DIFF(o.transaction_ts, s.session_start_ts, HOUR)) / 24 AS days_of_decision,
    COUNT(DISTINCT s.session_default_channel_group) AS channels_used,
    COUNT(DISTINCT s.device_category) AS devices_used
  FROM orders AS o
  JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.user_key = o.user_key
    AND s.session_start_ts BETWEEN TIMESTAMP_SUB(o.transaction_ts, INTERVAL 90 DAY) AND o.transaction_ts
  WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 270 DAY)
  GROUP BY 1, 2
)
SELECT
  is_high_ticket,
  COUNT(*) AS orders,
  APPROX_QUANTILES(sessions_before, 100)[OFFSET(50)] AS median_sessions,
  APPROX_QUANTILES(days_of_decision, 100)[OFFSET(50)] AS median_days,
  APPROX_QUANTILES(days_of_decision, 100)[OFFSET(90)] AS p90_days,
  AVG(channels_used) AS avg_channels,
  SAFE_DIVIDE(COUNTIF(devices_used >= 2), COUNT(*)) AS multi_device_share
FROM journeys
GROUP BY is_high_ticket;
-- the p90 of the days is the minimum length of the remarketing audience. A 7 day audience for a
-- 40 day decision throws away most of the buyers.

-- 2) installments: payment method and the order value (card + installments is the default here?)
SELECT
  COALESCE(LOWER(payment_type), '(not set)') AS payment_type,
  COUNT(*) AS orders,
  AVG(revenue) AS aov,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) AS share
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND revenue >= high_ticket AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
GROUP BY 1
ORDER BY orders DESC;

-- 3) the expensive products people leave to compare prices and do not come back (frontier)
SELECT item_name, item_category, median_price, departures, returned_share, never_returned_share,
       competitor_loss_index, returned_via_search_share, verdict
FROM `your-gcp-project.ga4_ecommerce.ecom_price_check_departures`
WHERE median_price >= high_ticket
ORDER BY departures * never_returned_share DESC
LIMIT 50;

-- 4) money in the pipeline of open carts and the people waiting for a better price (frontier)
SELECT cart_age_days, open_carts_now, open_cart_value_now, p_convert_in_horizon, expected_revenue, pipeline_pressure
FROM `your-gcp-project.ga4_ecommerce.ecom_cart_pipeline_forecast`
ORDER BY cart_age_days;

SELECT item_name, COUNT(*) AS watchers, COUNTIF(watch_status = 'hot') AS hot_watchers, AVG(price_change_since_first_view) AS avg_price_change
FROM `your-gcp-project.ga4_segments.seg_price_watchers`
WHERE current_price >= high_ticket
GROUP BY item_name
ORDER BY hot_watchers DESC
LIMIT 30;
