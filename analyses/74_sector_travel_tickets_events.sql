-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: travel, hotels, airlines, bus tickets, concerts, sports, theater (anything with a date)
-- the product expires. The questions: how far ahead people book, which routes / events are searched
-- and not bought, how the price sensitivity changes as the date gets close, and how fast an event
-- sells out. Set the params your search event sends (GA4 recommended travel params when possible).
-- With the mart on (cfg_extras.travel.enabled): ga4_ecommerce.ecom_travel_search_demand.

DECLARE search_event STRING DEFAULT 'search';
DECLARE destination_param STRING DEFAULT 'destination';
DECLARE start_date_param STRING DEFAULT 'start_date';

-- 1) the booking window: days between the purchase and the trip / event date, per destination
-- (the trip date comes in the item: item_variant or item_category3 often carry it, change below)
SELECT
  item_category AS destination_or_event,
  COUNT(DISTINCT transaction_id) AS orders,
  APPROX_QUANTILES(DATE_DIFF(SAFE.PARSE_DATE('%Y-%m-%d', item_variant), transaction_date, DAY), 100 IGNORE NULLS)[OFFSET(25)] AS p25_days_ahead,
  APPROX_QUANTILES(DATE_DIFF(SAFE.PARSE_DATE('%Y-%m-%d', item_variant), transaction_date, DAY), 100 IGNORE NULLS)[OFFSET(50)] AS median_days_ahead,
  APPROX_QUANTILES(DATE_DIFF(SAFE.PARSE_DATE('%Y-%m-%d', item_variant), transaction_date, DAY), 100 IGNORE NULLS)[OFFSET(75)] AS p75_days_ahead,
  AVG(price) AS avg_price
FROM `your-gcp-project.ga4_core.fct_transaction_items`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
  AND is_valid_for_revenue
GROUP BY 1
HAVING COUNT(DISTINCT transaction_id) >= 30
ORDER BY orders DESC;
-- the media for a destination should start BEFORE p75_days_ahead, not on the week of the trip

-- 2) demand not met: searched destinations vs bought destinations (last 90 days)
WITH searches AS (
  SELECT
    LOWER(TRIM((SELECT value.string_value FROM UNNEST(event_params) WHERE key = destination_param))) AS destination,
    COUNT(*) AS searches,
    COUNT(DISTINCT user_key) AS searchers
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND event_name = search_event
  GROUP BY 1
),
bought AS (
  SELECT LOWER(TRIM(item_category)) AS destination, COUNT(DISTINCT transaction_id) AS orders, SUM(item_revenue) AS revenue
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND is_valid_for_revenue
  GROUP BY 1
)
SELECT
  s.destination,
  s.searches,
  s.searchers,
  COALESCE(b.orders, 0) AS orders,
  COALESCE(b.revenue, 0) AS revenue,
  SAFE_DIVIDE(COALESCE(b.orders, 0), s.searchers) AS orders_per_searcher
FROM searches AS s
LEFT JOIN bought AS b USING (destination)
WHERE s.destination IS NOT NULL
ORDER BY s.searchers DESC
LIMIT 100;
-- top searched with orders_per_searcher close to zero: no inventory, wrong price, or the search is broken

-- 3) lead time of the SEARCH (search date -> trip date) and the booking rate in 14 days
WITH s AS (
  SELECT
    user_key,
    event_ts,
    DATE_DIFF(SAFE_CAST((SELECT COALESCE(value.string_value, CAST(value.int_value AS STRING)) FROM UNNEST(event_params) WHERE key = start_date_param) AS DATE), event_date, DAY) AS lead_days
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 104 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
    AND event_name = search_event
),
first_search AS (
  SELECT user_key, MIN(event_ts) AS ts, ARRAY_AGG(lead_days IGNORE NULLS ORDER BY event_ts LIMIT 1)[SAFE_OFFSET(0)] AS lead_days
  FROM s
  GROUP BY 1
),
orders AS (
  SELECT user_key, transaction_ts FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 104 DAY) AND is_valid_for_revenue
)
SELECT
  CASE
    WHEN f.lead_days IS NULL OR f.lead_days < 0 THEN '(no date)'
    WHEN f.lead_days < 3 THEN '01 last minute (<3d)'
    WHEN f.lead_days < 14 THEN '02 <2 weeks'
    WHEN f.lead_days < 30 THEN '03 <1 month'
    WHEN f.lead_days < 90 THEN '04 1-3 months'
    ELSE '05 3+ months'
  END AS lead_time,
  COUNT(DISTINCT f.user_key) AS searchers,
  SAFE_DIVIDE(COUNT(DISTINCT IF(o.user_key IS NOT NULL, f.user_key, NULL)), COUNT(DISTINCT f.user_key)) AS booking_rate_14d
FROM first_search AS f
LEFT JOIN orders AS o
  ON o.user_key = f.user_key
  AND o.transaction_ts BETWEEN f.ts AND TIMESTAMP_ADD(f.ts, INTERVAL 14 DAY)
GROUP BY 1
ORDER BY 1;
-- the far ahead searchers are dreamers: cheap remarketing + price alert, not expensive search bids

-- 4) sell out velocity of events / departures: units sold per day since the first sale, and the day 50% was sold
WITH daily AS (
  SELECT item_id, ANY_VALUE(item_name) AS item_name, transaction_date, SUM(quantity) AS units
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
    AND is_valid_for_revenue
  GROUP BY item_id, transaction_date
),
cum AS (
  SELECT
    *,
    SUM(units) OVER (PARTITION BY item_id ORDER BY transaction_date) AS cumulative_units,
    SUM(units) OVER (PARTITION BY item_id) AS total_units,
    MIN(transaction_date) OVER (PARTITION BY item_id) AS first_sale_date
  FROM daily
)
SELECT
  item_id,
  ANY_VALUE(item_name) AS item_name,
  ANY_VALUE(total_units) AS total_units,
  ANY_VALUE(first_sale_date) AS first_sale_date,
  MIN(IF(cumulative_units >= total_units * 0.5, DATE_DIFF(transaction_date, first_sale_date, DAY), NULL)) AS days_to_sell_half,
  MAX(units) AS best_day_units,
  ARRAY_AGG(transaction_date ORDER BY units DESC LIMIT 1)[OFFSET(0)] AS best_day
FROM cum
GROUP BY item_id
HAVING ANY_VALUE(total_units) >= 50
ORDER BY days_to_sell_half
LIMIT 50;
-- half sold in 2 days = under priced (or the next date should open sooner)
