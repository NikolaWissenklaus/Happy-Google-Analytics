-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: food delivery, restaurants, dark kitchens, bakeries, grocery delivery (local, by the hour)
-- the business runs by city and by meal time. The questions: day parts, kitchen capacity at the
-- peak, minimum order, weekly habit (the "pizza on friday" customer) and the cities that order.
-- Set your minimum order value below (used in 4).

DECLARE minimum_order FLOAT64 DEFAULT 30;

-- 1) orders per day part and city (local time), with the AOV of each meal
SELECT
  geo_city,
  CASE
    WHEN EXTRACT(HOUR FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) BETWEEN 6 AND 10 THEN '1_breakfast'
    WHEN EXTRACT(HOUR FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) BETWEEN 11 AND 14 THEN '2_lunch'
    WHEN EXTRACT(HOUR FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) BETWEEN 15 AND 17 THEN '3_afternoon'
    WHEN EXTRACT(HOUR FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) BETWEEN 18 AND 22 THEN '4_dinner'
    ELSE '5_late_night'
  END AS day_part,
  COUNT(*) AS orders,
  AVG(revenue) AS aov,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY geo_city)) AS share_in_city
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
GROUP BY 1, 2
HAVING COUNT(*) >= 20
ORDER BY geo_city, day_part;

-- 2) the kitchen peak: orders per 15 minutes, worst slots of the week (capacity planning)
SELECT
  EXTRACT(DAYOFWEEK FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) AS weekday_sunday_1,
  FORMAT_TIME('%H:%M', TIME(TIMESTAMP_SECONDS(DIV(UNIX_SECONDS(transaction_ts), 900) * 900), 'America/Sao_Paulo')) AS slot_15min,
  COUNT(*) / COUNT(DISTINCT transaction_date) AS avg_orders_in_slot,
  MAX(cnt) AS max_orders_in_slot
FROM (
  SELECT transaction_ts, transaction_date,
    COUNT(*) OVER (PARTITION BY transaction_date, DIV(UNIX_SECONDS(transaction_ts), 900)) AS cnt
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 56 DAY)
)
GROUP BY 1, 2
ORDER BY max_orders_in_slot DESC
LIMIT 30;

-- 3) weekly habit: customers that order on the SAME weekday most of the time (send the offer
-- the day before their day, not on a random tuesday)
WITH orders AS (
  SELECT user_key, EXTRACT(DAYOFWEEK FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) AS weekday, COUNT(*) AS n
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY 1, 2
)
SELECT
  user_key,
  ARRAY_AGG(weekday ORDER BY n DESC LIMIT 1)[OFFSET(0)] AS favourite_weekday_sunday_1,
  SUM(n) AS orders,
  SAFE_DIVIDE(MAX(n), SUM(n)) AS weekday_loyalty
FROM orders
GROUP BY user_key
HAVING SUM(n) >= 4 AND SAFE_DIVIDE(MAX(n), SUM(n)) >= 0.5
ORDER BY orders DESC
LIMIT 500;

-- 4) minimum order: carts abandoned just below the minimum (set yours) vs orders right above it
SELECT
  COUNTIF(is_cart_abandoned AND cart_value BETWEEN minimum_order - 10 AND minimum_order) AS carts_dead_below_minimum,
  COUNTIF(has_purchase AND revenue BETWEEN minimum_order AND minimum_order + 10) AS orders_just_above_minimum
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY) AND NOT is_bot_suspect;
