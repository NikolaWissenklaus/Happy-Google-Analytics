-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- when do people buy (and when do they only browse)?
-- answers: when to send the email / push / WhatsApp, when to raise the bids, when the support
-- team needs more people, when to schedule the deploy (the quietest hour). Last 90 days, local time.

-- 1) weekday x hour heatmap: sessions, orders, conversion, revenue
SELECT
  session_iso_weekday AS iso_weekday,
  session_hour AS hour,
  COUNT(*) AS sessions,
  SUM(transactions) AS orders,
  SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate,
  SUM(revenue) AS revenue,
  SAFE_DIVIDE(SUM(revenue), SUM(SUM(revenue)) OVER ()) AS share_of_revenue,
  -- index 100 = average conversion of the week. above 120 = golden hour
  100 * SAFE_DIVIDE(SAFE_DIVIDE(SUM(transactions), COUNT(*)), SUM(SUM(transactions)) OVER () / SUM(COUNT(*)) OVER ()) AS conversion_index
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND NOT is_bot_suspect
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2) browse now, buy later: the hour people DISCOVER (first session of the journey) vs the hour
-- they BUY. Ads at the discovery hour, CRM at the buying hour
WITH first_touch AS (
  SELECT t.transaction_id,
    ARRAY_AGG(s.session_hour ORDER BY s.session_start_ts LIMIT 1)[OFFSET(0)] AS discovery_hour
  FROM `your-gcp-project.ga4_core.fct_transactions` AS t
  JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.user_key = t.user_key
    AND s.session_start_ts BETWEEN TIMESTAMP_SUB(t.transaction_ts, INTERVAL 30 DAY) AND t.transaction_ts
  WHERE t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND t.is_valid_for_revenue
    AND s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY t.transaction_id
)
SELECT
  f.discovery_hour,
  EXTRACT(HOUR FROM DATETIME(t.transaction_ts, 'America/Sao_Paulo')) AS purchase_hour,
  COUNT(*) AS orders
FROM first_touch AS f
JOIN `your-gcp-project.ga4_core.fct_transactions` AS t USING (transaction_id)
GROUP BY 1, 2
ORDER BY orders DESC
LIMIT 50;

-- 3) best send time per segment of customers (hour where each customer bought most often):
-- an email at 7h for people that buy at 22h goes to the bottom of the inbox
WITH customer_hours AS (
  SELECT user_key, EXTRACT(HOUR FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) AS hour, COUNT(*) AS orders
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
  GROUP BY 1, 2
)
SELECT
  CASE
    WHEN favourite_hour BETWEEN 5 AND 11 THEN '1_morning'
    WHEN favourite_hour BETWEEN 12 AND 13 THEN '2_lunch'
    WHEN favourite_hour BETWEEN 14 AND 17 THEN '3_afternoon'
    WHEN favourite_hour BETWEEN 18 AND 21 THEN '4_evening'
    ELSE '5_night'
  END AS send_window,
  COUNT(*) AS customers
FROM (
  SELECT user_key, ARRAY_AGG(hour ORDER BY orders DESC, hour LIMIT 1)[OFFSET(0)] AS favourite_hour
  FROM customer_hours
  GROUP BY user_key
)
GROUP BY send_window
ORDER BY send_window;

-- 4) the quietest hour of the week for deploys and maintenance (fewest sessions and revenue)
SELECT session_iso_weekday, session_hour, COUNT(*) AS sessions, SUM(revenue) AS revenue
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
GROUP BY 1, 2
ORDER BY revenue, sessions
LIMIT 5;
