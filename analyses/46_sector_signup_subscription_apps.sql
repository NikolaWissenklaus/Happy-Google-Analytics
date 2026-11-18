-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: subscriptions, clubs, SaaS, apps, marketplaces with accounts (the sign up is the first sale)
-- a sign up that never activates is a cost. The questions: which channel brings sign ups that
-- turn into paying customers, how fast, and what the activated users did in the first days.
-- Set the sign up event and the "value" event (purchase, subscribe, start_trial...).

DECLARE signup_event STRING DEFAULT 'sign_up';
DECLARE value_events ARRAY<STRING> DEFAULT ['purchase', 'subscribe', 'start_subscription', 'begin_trial'];

-- 1) sign up -> value event within 7 / 30 days, per channel of the sign up session
WITH signups AS (
  SELECT user_key, MIN(event_ts) AS signup_ts,
    ARRAY_AGG(session_default_channel_group ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS signup_channel
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = signup_event
  GROUP BY user_key
),
values_after AS (
  SELECT s.user_key, MIN(e.event_ts) AS first_value_ts
  FROM signups AS s
  JOIN `your-gcp-project.ga4_core.fct_events` AS e
    ON e.user_key = s.user_key
    AND e.event_ts >= s.signup_ts
    AND e.event_ts <= TIMESTAMP_ADD(s.signup_ts, INTERVAL 30 DAY)
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
    AND e.event_name IN UNNEST(value_events)
  GROUP BY s.user_key
)
SELECT
  s.signup_channel,
  COUNT(*) AS signups,
  SAFE_DIVIDE(COUNTIF(TIMESTAMP_DIFF(v.first_value_ts, s.signup_ts, HOUR) <= 24 * 7), COUNT(*)) AS activation_7d,
  SAFE_DIVIDE(COUNTIF(v.first_value_ts IS NOT NULL), COUNT(*)) AS activation_30d,
  APPROX_QUANTILES(TIMESTAMP_DIFF(v.first_value_ts, s.signup_ts, HOUR), 100 IGNORE NULLS)[OFFSET(50)] AS median_hours_to_value
FROM signups AS s
LEFT JOIN values_after AS v USING (user_key)
GROUP BY 1
HAVING COUNT(*) >= 30
ORDER BY signups DESC;

-- 2) what the activated users did in their first 3 days that the others did not (events per user)
WITH signups AS (
  SELECT user_key, MIN(event_ts) AS signup_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = signup_event
  GROUP BY user_key
),
activity AS (
  SELECT s.user_key, e.event_name,
    COUNTIF(e.event_ts <= TIMESTAMP_ADD(s.signup_ts, INTERVAL 3 DAY)) AS events_first_3d,
    COUNTIF(e.event_name IN UNNEST(value_events)) > 0 AS is_value_event
  FROM signups AS s
  JOIN `your-gcp-project.ga4_core.fct_events` AS e
    ON e.user_key = s.user_key AND e.event_ts BETWEEN s.signup_ts AND TIMESTAMP_ADD(s.signup_ts, INTERVAL 30 DAY)
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY 1, 2
),
activated AS (
  SELECT user_key, LOGICAL_OR(is_value_event) AS activated FROM activity GROUP BY user_key
),
totals AS (
  SELECT COUNTIF(activated) AS activated_users, COUNTIF(NOT activated) AS not_activated_users FROM activated
),
by_event AS (
  SELECT
    a.event_name,
    COUNT(DISTINCT IF(x.activated AND a.events_first_3d > 0, a.user_key, NULL)) AS activated_doing_it,
    COUNT(DISTINCT IF(NOT x.activated AND a.events_first_3d > 0, a.user_key, NULL)) AS not_activated_doing_it
  FROM activity AS a
  JOIN activated AS x USING (user_key)
  WHERE a.event_name NOT IN UNNEST(value_events)
  GROUP BY a.event_name
)
SELECT
  e.event_name,
  SAFE_DIVIDE(e.activated_doing_it, t.activated_users) AS share_of_activated_doing_it,
  SAFE_DIVIDE(e.not_activated_doing_it, t.not_activated_users) AS share_of_not_activated_doing_it,
  SAFE_DIVIDE(SAFE_DIVIDE(e.activated_doing_it, t.activated_users), NULLIF(SAFE_DIVIDE(e.not_activated_doing_it, t.not_activated_users), 0)) AS aha_ratio
FROM by_event AS e
CROSS JOIN totals AS t
WHERE e.activated_doing_it + e.not_activated_doing_it >= 30
ORDER BY aha_ratio DESC;
-- the events with the biggest ratio are the "aha moments": push the new users to them
-- (the model version is ga4_product.prod_aha_moments)

-- 3) weekly active users vs monthly (stickiness) for the app / logged area
SELECT
  activity_date,
  COUNT(DISTINCT user_key) AS dau
FROM `your-gcp-project.ga4_core.fct_user_daily`
WHERE activity_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY 1
ORDER BY 1;
-- DAU / MAU and the L28 curve: ga4_product.prod_active_users_daily, prod_power_user_curve
