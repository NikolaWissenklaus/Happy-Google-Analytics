-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- ANY BUSINESS: the 15 journeys that explain most of the customers
-- attribution models give credit, they do not show the SHAPE of the journey. Here: the sequence of
-- channels of the first 3 sessions of every new user (first seen between 120 and 30 days ago), how
-- many people follow each shape, how many of them bought in 30 days, and the money. Then the same
-- by "role": what usually opens and what usually closes.

-- 1) channel sequences of the first 3 sessions
WITH new_users AS (
  SELECT user_key, first_seen_date
  FROM `your-gcp-project.ga4_core.dim_users`
  WHERE first_seen_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
),
first_sessions AS (
  SELECT
    s.user_key,
    s.session_default_channel_group AS channel,
    ROW_NUMBER() OVER (PARTITION BY s.user_key ORDER BY s.session_start_ts) AS n
  FROM `your-gcp-project.ga4_core.fct_sessions` AS s
  JOIN new_users AS u
    ON u.user_key = s.user_key
    AND s.session_date BETWEEN u.first_seen_date AND DATE_ADD(u.first_seen_date, INTERVAL 29 DAY)
  WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
    AND NOT s.is_bot_suspect
),
sequences AS (
  SELECT
    user_key,
    STRING_AGG(channel, ' > ' ORDER BY n) AS journey,
    MAX(n) AS sessions_in_30d
  FROM first_sessions
  WHERE n <= 3
  GROUP BY 1
),
value_30d AS (
  SELECT u.user_key, SUM(t.revenue) AS revenue
  FROM new_users AS u
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = u.user_key
    AND t.transaction_date BETWEEN u.first_seen_date AND DATE_ADD(u.first_seen_date, INTERVAL 29 DAY)
  WHERE t.is_valid_for_revenue
    AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY 1
)
SELECT
  s.journey,
  COUNT(*) AS users,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) AS share_of_users,
  SAFE_DIVIDE(COUNTIF(v.revenue > 0), COUNT(*)) AS buyer_rate_30d,
  SUM(COALESCE(v.revenue, 0)) AS revenue_30d,
  SAFE_DIVIDE(SUM(COALESCE(v.revenue, 0)), SUM(SUM(COALESCE(v.revenue, 0))) OVER ()) AS share_of_revenue
FROM sequences AS s
LEFT JOIN value_30d AS v USING (user_key)
GROUP BY 1
HAVING COUNT(*) >= 50
ORDER BY revenue_30d DESC
LIMIT 15;
-- "Paid Social > Direct > Organic Search" with a high share of revenue: social opens, the brand closes.
-- Cutting Paid Social because its last click ROAS is low kills the top of this journey

-- 2) openers and closers: for each channel, the share of the journeys it opens and the share it closes
-- (among buyers: the channel of the purchase session vs the channel of the first session)
WITH buyers AS (
  SELECT
    t.user_key,
    t.session_default_channel_group AS closer,
    u.first_channel AS opener,
    t.revenue
  FROM `your-gcp-project.ga4_core.fct_transactions` AS t
  JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
  WHERE t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND t.is_valid_for_revenue
    AND t.is_first_purchase
)
SELECT
  channel,
  SUM(opened) AS journeys_opened,
  SUM(closed) AS journeys_closed,
  SAFE_DIVIDE(SUM(opened), SUM(closed)) AS opener_to_closer_ratio,
  CASE
    WHEN SAFE_DIVIDE(SUM(opened), SUM(closed)) >= 1.3 THEN 'opener (judge it by first touch / assisted)'
    WHEN SAFE_DIVIDE(SUM(opened), SUM(closed)) <= 0.7 THEN 'closer (last click flatters it)'
    ELSE 'both'
  END AS role
FROM (
  SELECT opener AS channel, 1 AS opened, 0 AS closed FROM buyers
  UNION ALL
  SELECT closer, 0, 1 FROM buyers
)
GROUP BY 1
HAVING SUM(opened) + SUM(closed) >= 30
ORDER BY journeys_opened + journeys_closed DESC;

-- 3) the same journey, different outcome: for the most common journey shape, what the buyers did
-- that the non buyers did not (cart, search, engaged sessions, pages)
WITH new_users AS (
  SELECT user_key, first_seen_date
  FROM `your-gcp-project.ga4_core.dim_users`
  WHERE first_seen_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
),
first_30d AS (
  SELECT
    s.user_key,
    COUNT(*) AS sessions,
    COUNTIF(s.is_engaged) AS engaged_sessions,
    SUM(s.page_views) AS page_views,
    LOGICAL_OR(s.has_site_search) AS searched,
    LOGICAL_OR(s.has_add_to_cart) AS carted,
    LOGICAL_OR(s.has_purchase) AS bought,
    COUNT(DISTINCT s.session_default_channel_group) AS channels
  FROM `your-gcp-project.ga4_core.fct_sessions` AS s
  JOIN new_users AS u
    ON u.user_key = s.user_key
    AND s.session_date BETWEEN u.first_seen_date AND DATE_ADD(u.first_seen_date, INTERVAL 29 DAY)
  WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
    AND NOT s.is_bot_suspect
  GROUP BY 1
)
SELECT
  bought,
  COUNT(*) AS users,
  AVG(sessions) AS avg_sessions,
  AVG(engaged_sessions) AS avg_engaged_sessions,
  AVG(page_views) AS avg_page_views,
  AVG(IF(searched, 1, 0)) AS searched_share,
  AVG(IF(carted, 1, 0)) AS carted_share,
  AVG(channels) AS avg_distinct_channels
FROM first_30d
WHERE sessions >= 2
GROUP BY 1;
