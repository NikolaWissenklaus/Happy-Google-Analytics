-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- ANY BUSINESS: people research in one place and buy in another (device, day of the week, app / web)
-- last click reports give all the credit to the desktop session of tuesday morning, and the mobile
-- sessions of the weekend that created the desire look useless. Only works for stitched users
-- (user_key with login / identity graph), so read the share of identified buyers first (query 0).

-- 0) how much of this can we see? share of the buyers with more than one device / session
SELECT
  COUNT(*) AS buyers,
  SAFE_DIVIDE(COUNTIF(is_identified), COUNT(*)) AS identified_share,
  SAFE_DIVIDE(COUNTIF(device_categories > 1), COUNT(*)) AS multi_device_share,
  SAFE_DIVIDE(COUNTIF(sessions > 1), COUNT(*)) AS multi_session_share
FROM `your-gcp-project.ga4_core.dim_users`
WHERE is_customer
  AND last_purchase_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);

-- 1) research device x purchase device: devices of the sessions in the 7 days before the purchase
WITH purchases AS (
  SELECT transaction_id, user_key, transaction_ts, session_key, device_category AS purchase_device
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND is_valid_for_revenue
),
research AS (
  SELECT
    p.transaction_id,
    p.purchase_device,
    ARRAY_AGG(DISTINCT s.device_category IGNORE NULLS) AS research_devices
  FROM purchases AS p
  JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.user_key = p.user_key
    AND s.session_start_ts BETWEEN TIMESTAMP_SUB(p.transaction_ts, INTERVAL 7 DAY) AND p.transaction_ts
    AND s.session_key != p.session_key
  WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 97 DAY)
  GROUP BY 1, 2
)
SELECT
  p.purchase_device,
  COUNT(*) AS purchases,
  SAFE_DIVIDE(COUNTIF(r.transaction_id IS NULL), COUNT(*)) AS no_previous_session_7d,
  SAFE_DIVIDE(COUNTIF('mobile' IN UNNEST(r.research_devices)), COUNT(*)) AS researched_on_mobile,
  SAFE_DIVIDE(COUNTIF('desktop' IN UNNEST(r.research_devices)), COUNT(*)) AS researched_on_desktop,
  SAFE_DIVIDE(COUNTIF(p.purchase_device NOT IN UNNEST(r.research_devices) AND ARRAY_LENGTH(r.research_devices) > 0), COUNT(*)) AS researched_only_on_other_device
FROM purchases AS p
LEFT JOIN research AS r USING (transaction_id)
GROUP BY 1
ORDER BY purchases DESC;
-- desktop purchases with 40% "researched on mobile": the mobile CVR is not the mobile value

-- 2) weekend research, weekday purchase: weekday of the purchase x weekday of the first session of the decision
WITH purchases AS (
  SELECT transaction_id, user_key, transaction_ts,
    EXTRACT(DAYOFWEEK FROM DATETIME(transaction_ts, 'America/Sao_Paulo')) AS purchase_weekday
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND is_valid_for_revenue
),
first_touch AS (
  SELECT
    p.transaction_id,
    p.purchase_weekday,
    EXTRACT(DAYOFWEEK FROM DATETIME(MIN(s.session_start_ts), 'America/Sao_Paulo')) AS first_session_weekday
  FROM purchases AS p
  JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.user_key = p.user_key
    AND s.session_start_ts BETWEEN TIMESTAMP_SUB(p.transaction_ts, INTERVAL 14 DAY) AND p.transaction_ts
  WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 104 DAY)
  GROUP BY 1, 2
)
SELECT
  first_session_weekday,
  purchase_weekday,
  COUNT(*) AS purchases,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY purchase_weekday)) AS share_of_purchase_weekday
FROM first_touch
GROUP BY 1, 2
ORDER BY 2, 1;
-- (1 = sunday). A heavy sunday row for monday / tuesday purchases = the media of the weekend is the
-- one that fills the week: do not cut it because its own ROAS is low

-- 3) app x web: value per user of who uses only web, only app or both, per month
WITH monthly AS (
  SELECT
    DATE_TRUNC(activity_date, MONTH) AS month_start,
    user_key,
    LOGICAL_OR(used_web) AS web,
    LOGICAL_OR(used_app) AS app,
    SUM(revenue) AS revenue,
    SUM(transactions) AS transactions,
    SUM(sessions) AS sessions
  FROM `your-gcp-project.ga4_core.fct_user_daily`
  WHERE activity_date >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH), MONTH)
  GROUP BY 1, 2
)
SELECT
  month_start,
  CASE WHEN web AND app THEN 'both' WHEN app THEN 'app only' ELSE 'web only' END AS platform_mix,
  COUNT(*) AS users,
  SAFE_DIVIDE(COUNTIF(transactions > 0), COUNT(*)) AS buyer_rate,
  SAFE_DIVIDE(SUM(revenue), COUNT(*)) AS revenue_per_user,
  SAFE_DIVIDE(SUM(sessions), COUNT(*)) AS sessions_per_user
FROM monthly
GROUP BY 1, 2
ORDER BY 1, 2;
-- "both" worth 3x "web only" is the business case of the app download banner (and of the login)
