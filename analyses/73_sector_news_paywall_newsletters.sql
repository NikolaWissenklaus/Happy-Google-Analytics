-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: news, magazines, newsletters, any site with a meter / paywall
-- 45_sector_publishers_content_sites.sql covers reading and ad revenue. This one is about the
-- reader revenue: how tight the meter should be, which sections sell the subscription, what the
-- subscribers read before subscribing, and whether the newsletter is the bridge.
-- With the mart on (cfg_extras.news_paywall.enabled): ga4_product.prod_news_paywall_funnel per week.

DECLARE paywall_event STRING DEFAULT 'paywall_view';
DECLARE subscribe_events ARRAY<STRING> DEFAULT ['purchase', 'subscribe'];
DECLARE newsletter_event STRING DEFAULT 'newsletter_signup';

-- 1) the meter curve: of the readers that read N articles in 30 days, how many subscribed?
-- where the curve bends is where the meter should block
WITH reads AS (
  SELECT user_key, COUNT(*) AS articles_30d
  FROM `your-gcp-project.ga4_core.fct_page_views`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND page_type IN ('article', 'blog', 'content')
  GROUP BY user_key
),
subs AS (
  SELECT DISTINCT user_key
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name IN UNNEST(subscribe_events)
)
SELECT
  LEAST(r.articles_30d, 30) AS articles_read_30d,
  COUNT(*) AS readers,
  COUNTIF(s.user_key IS NOT NULL) AS subscribers,
  SAFE_DIVIDE(COUNTIF(s.user_key IS NOT NULL), COUNT(*)) AS subscribe_rate,
  SAFE_DIVIDE(SUM(COUNT(*)) OVER (ORDER BY LEAST(r.articles_30d, 30) DESC), SUM(COUNT(*)) OVER ()) AS share_of_readers_with_at_least_n
FROM reads AS r
LEFT JOIN subs AS s USING (user_key)
GROUP BY 1
ORDER BY 1;
-- "share_of_readers_with_at_least_n" = how many people a meter of N articles would block

-- 2) the paywall per section: hits, conversion in the same session and in 7 days
WITH paywalls AS (
  SELECT
    e.user_key,
    e.session_key,
    e.event_ts,
    COALESCE(NULLIF(e.content_group, '(not set)'), REGEXP_EXTRACT(e.page_path, r'^/([^/]+)'), '(home)') AS section
  FROM `your-gcp-project.ga4_core.fct_events` AS e
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
    AND e.event_name = paywall_event
),
subs AS (
  SELECT user_key, session_key, event_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
    AND event_name IN UNNEST(subscribe_events)
),
outcome AS (
  SELECT
    p.section,
    p.user_key,
    LOGICAL_OR(s.session_key = p.session_key) AS same_session,
    LOGICAL_OR(s.event_ts IS NOT NULL) AS within_7d
  FROM paywalls AS p
  LEFT JOIN subs AS s
    ON s.user_key = p.user_key
    AND s.event_ts BETWEEN p.event_ts AND TIMESTAMP_ADD(p.event_ts, INTERVAL 7 DAY)
  GROUP BY 1, 2
)
SELECT
  section,
  COUNT(*) AS readers_blocked,
  SAFE_DIVIDE(COUNTIF(same_session), COUNT(*)) AS subscribe_same_session,
  SAFE_DIVIDE(COUNTIF(within_7d), COUNT(*)) AS subscribe_within_7d
FROM outcome
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY readers_blocked DESC;

-- 3) what the new subscribers read in the 30 days before subscribing vs the readers that did not
WITH subs AS (
  SELECT user_key, MIN(event_ts) AS subscribe_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
    AND event_name IN UNNEST(subscribe_events)
  GROUP BY user_key
),
reads AS (
  SELECT
    pv.user_key,
    COALESCE(NULLIF(pv.content_group, '(not set)'), REGEXP_EXTRACT(pv.page_path, r'^/([^/]+)'), '(home)') AS section,
    s.user_key IS NOT NULL AS is_subscriber
  FROM `your-gcp-project.ga4_core.fct_page_views` AS pv
  LEFT JOIN subs AS s
    ON s.user_key = pv.user_key
  WHERE pv.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND pv.page_type IN ('article', 'blog', 'content')
    AND (s.user_key IS NULL OR pv.event_ts BETWEEN TIMESTAMP_SUB(s.subscribe_ts, INTERVAL 30 DAY) AND s.subscribe_ts)
),
totals AS (
  SELECT is_subscriber, COUNT(*) AS views FROM reads GROUP BY 1
)
SELECT
  r.section,
  SAFE_DIVIDE(COUNTIF(r.is_subscriber), ANY_VALUE(ts.views)) AS share_of_subscriber_reading,
  SAFE_DIVIDE(COUNTIF(NOT r.is_subscriber), ANY_VALUE(tn.views)) AS share_of_non_subscriber_reading,
  SAFE_DIVIDE(SAFE_DIVIDE(COUNTIF(r.is_subscriber), ANY_VALUE(ts.views)), SAFE_DIVIDE(COUNTIF(NOT r.is_subscriber), ANY_VALUE(tn.views))) AS subscriber_index
FROM reads AS r
CROSS JOIN (SELECT views FROM totals WHERE is_subscriber) AS ts
CROSS JOIN (SELECT views FROM totals WHERE NOT is_subscriber) AS tn
GROUP BY 1
HAVING COUNT(*) >= 200
ORDER BY subscriber_index DESC;
-- index 2+ = the section subscribers read twice as much: the section that sells the plan

-- 4) is the newsletter the bridge? subscription rate of newsletter sign ups vs everybody, by days since sign up
WITH nl AS (
  SELECT user_key, MIN(event_ts) AS signup_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 150 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
    AND event_name = newsletter_event
  GROUP BY user_key
),
subs AS (
  SELECT user_key, MIN(event_ts) AS subscribe_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 150 DAY)
    AND event_name IN UNNEST(subscribe_events)
  GROUP BY user_key
)
SELECT
  COUNT(*) AS newsletter_signups,
  SAFE_DIVIDE(COUNTIF(TIMESTAMP_DIFF(s.subscribe_ts, n.signup_ts, DAY) BETWEEN 0 AND 7), COUNT(*)) AS subscribed_7d,
  SAFE_DIVIDE(COUNTIF(TIMESTAMP_DIFF(s.subscribe_ts, n.signup_ts, DAY) BETWEEN 0 AND 30), COUNT(*)) AS subscribed_30d,
  SAFE_DIVIDE(COUNTIF(TIMESTAMP_DIFF(s.subscribe_ts, n.signup_ts, DAY) BETWEEN 0 AND 60), COUNT(*)) AS subscribed_60d,
  APPROX_QUANTILES(IF(s.subscribe_ts >= n.signup_ts, TIMESTAMP_DIFF(s.subscribe_ts, n.signup_ts, DAY), NULL), 100 IGNORE NULLS)[OFFSET(50)] AS median_days_to_subscribe
FROM nl AS n
LEFT JOIN subs AS s USING (user_key);
