-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the GA4 BigQuery export from zero, for the first week of a junior analyst.
-- part A reads the RAW export (to understand it), part B does the same with the core tables of
-- this project (what you should use every day, with the fixes already applied).
-- replace `your-gcp-project.analytics_123456789` by your export and `ga4_` by your schema_prefix.

-- ============================================================ A. the raw export

-- A1) one table per day (events_YYYYMMDD). ALWAYS filter _TABLE_SUFFIX, or you pay for every day ever
SELECT event_date, COUNT(*) AS events, COUNT(DISTINCT user_pseudo_id) AS devices
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
                        AND FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1
ORDER BY 1;

-- A2) the event names of yesterday. Case matters: 'Add_To_Cart' and 'add_to_cart' are 2 events for GA4
SELECT event_name, COUNT(*) AS events
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1
ORDER BY 2 DESC;

-- A3) params live in an ARRAY of key / value, and the value has 4 typed columns. A param can arrive as
-- string in one event and as int in another: read all of them (or use ga4_udf.get_param_any)
SELECT
  event_name,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
  (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64), SAFE_CAST(value.string_value AS INT64))
   FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
LIMIT 100;

-- A4) every param that exists and its type mix (when a param comes as 2 types, someone changed the tag)
SELECT
  p.key,
  COUNTIF(p.value.string_value IS NOT NULL) AS as_string,
  COUNTIF(p.value.int_value IS NOT NULL) AS as_int,
  COUNTIF(p.value.double_value IS NOT NULL OR p.value.float_value IS NOT NULL) AS as_number
FROM `your-gcp-project.analytics_123456789.events_*`, UNNEST(event_params) AS p
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1
ORDER BY as_string + as_int + as_number DESC;

-- A5) a session is user_pseudo_id + ga_session_id. ga_session_id ALONE is not unique (it is a timestamp)
SELECT
  COUNT(DISTINCT CONCAT(user_pseudo_id, '.', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING))) AS sessions,
  COUNT(DISTINCT (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')) AS distinct_ga_session_ids_wrong
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY));

-- A6) event_timestamp is UTC microseconds, event_date is already the property timezone
SELECT
  event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_ts_utc,
  DATETIME(TIMESTAMP_MICROS(event_timestamp), 'America/Sao_Paulo') AS event_local
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
LIMIT 10;

-- A7) purchases and their items (items is another ARRAY). Revenue can be in 3 places, they do not always agree
SELECT
  ecommerce.transaction_id,
  ecommerce.purchase_revenue,
  (SELECT COALESCE(value.double_value, value.float_value, CAST(value.int_value AS FLOAT64)) FROM UNNEST(event_params) WHERE key = 'value') AS value_param,
  (SELECT SUM(i.price * i.quantity) FROM UNNEST(items) AS i) AS sum_of_items,
  ARRAY_LENGTH(items) AS lines
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
  AND event_name = 'purchase';

-- A8) the same transaction_id sent twice (the thank you page reloaded) is the most common revenue bug
SELECT ecommerce.transaction_id, COUNT(*) AS times_sent
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
                        AND FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
  AND event_name = 'purchase'
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY 2 DESC;

-- A9) consent: events with denied analytics storage arrive WITHOUT user_pseudo_id (cookieless pings)
SELECT privacy_info.analytics_storage, user_pseudo_id IS NULL AS cookieless, COUNT(*) AS events
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1, 2;

-- A10) traffic_source is the FIRST source of the user (forever), not of the session. The session one is
-- collected_traffic_source (event level) or session_traffic_source_last_click (since jul/2024)
SELECT
  traffic_source.source AS first_user_source,
  collected_traffic_source.manual_source AS event_source,
  session_traffic_source_last_click.cross_channel_campaign.source AS ga4_session_source,
  COUNT(*) AS events
FROM `your-gcp-project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
  AND event_name = 'session_start'
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 30;

-- ============================================================ B. the same with the core tables

-- B1) sessions, users and conversion of the last 7 days (bots out, fixes in)
SELECT
  session_date,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_key) AS people,
  SAFE_DIVIDE(COUNTIF(is_engaged), COUNT(*)) AS engagement_rate,
  SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate,
  SUM(revenue) AS revenue
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND NOT is_bot_suspect
GROUP BY 1
ORDER BY 1;

-- B2) channels (last non-direct click, the GA4 rule) with the official revenue
SELECT session_default_channel_group, COUNT(*) AS sessions, SUM(transactions) AS orders, SUM(revenue) AS revenue
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
  AND NOT is_bot_suspect
GROUP BY 1
ORDER BY revenue DESC;

-- B3) landing pages with engagement and conversion (UA bounce next to the GA4 one)
SELECT landing_page_path, COUNT(*) AS sessions,
  SAFE_DIVIDE(COUNTIF(is_bounce_ua), COUNT(*)) AS ua_bounce_rate,
  SAFE_DIVIDE(COUNTIF(is_bounce_ga4), COUNT(*)) AS ga4_bounce_rate,
  SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
  AND NOT is_bot_suspect
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY sessions DESC;

-- B4) the official revenue lives in fct_transactions (deduplicated, tests and outliers out)
SELECT transaction_date, COUNT(*) AS orders, SUM(revenue) AS revenue, SUM(net_revenue) AS net_revenue, AVG(revenue) AS aov
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue
  AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
GROUP BY 1
ORDER BY 1;

-- B5) users across days: NEVER sum daily users. Distinct over the period, or HLL sketches of the marts
SELECT
  COUNT(DISTINCT user_key) AS people_28d,
  (SELECT SUM(daily) FROM (SELECT COUNT(DISTINCT user_key) AS daily FROM `your-gcp-project.ga4_core.fct_sessions`
    WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY) GROUP BY session_date)) AS sum_of_daily_users_wrong
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY);

-- B6) the top products of the month with the funnel of each one
SELECT item_name, SUM(lifetime_views) AS views, SUM(lifetime_add_to_carts) AS carts, SUM(lifetime_units_sold) AS units
FROM `your-gcp-project.ga4_core.dim_items`
GROUP BY 1
ORDER BY units DESC
LIMIT 20;

-- B7) one person, every session (support / investigations). user_key joins all the devices of a logged person
SELECT session_start_ts, device_category, session_default_channel_group, landing_page_path, page_views, transactions, revenue
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE user_key = 'uid:12345'
ORDER BY session_start_ts;
