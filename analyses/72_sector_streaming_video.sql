-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: streaming, video on demand, podcasts, online courses with video, live sports
-- the product is time watched. The questions: which titles bring people back, which titles sell the
-- plan, when people binge, where they stop watching, and who is fading before cancelling.
-- Works with the enhanced measurement video events (video_start / progress / complete with
-- video_title) or with your own player events: change the names below.
-- With the mart on (cfg_extras.streaming.enabled): ga4_product.prod_streaming_titles.

DECLARE play_event STRING DEFAULT 'video_start';
DECLARE progress_event STRING DEFAULT 'video_progress';
DECLARE complete_event STRING DEFAULT 'video_complete';
DECLARE subscribe_events ARRAY<STRING> DEFAULT ['purchase', 'subscribe', 'start_subscription'];

-- 1) the drop off curve per title: share of the plays that reached 10/25/50/75/90% and complete
WITH media AS (
  SELECT
    video_title,
    event_name,
    video_percent,
    user_key,
    session_key
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name IN (play_event, progress_event, complete_event)
    AND video_title IS NOT NULL
)
SELECT
  video_title,
  COUNTIF(event_name = play_event) AS plays,
  COUNT(DISTINCT user_key) AS viewers,
  SAFE_DIVIDE(COUNTIF(event_name = progress_event AND video_percent = 10), COUNTIF(event_name = play_event)) AS reached_10,
  SAFE_DIVIDE(COUNTIF(event_name = progress_event AND video_percent = 25), COUNTIF(event_name = play_event)) AS reached_25,
  SAFE_DIVIDE(COUNTIF(event_name = progress_event AND video_percent = 50), COUNTIF(event_name = play_event)) AS reached_50,
  SAFE_DIVIDE(COUNTIF(event_name = progress_event AND video_percent = 75), COUNTIF(event_name = play_event)) AS reached_75,
  SAFE_DIVIDE(COUNTIF(event_name = complete_event), COUNTIF(event_name = play_event)) AS completed
FROM media
GROUP BY 1
HAVING COUNTIF(event_name = play_event) >= 100
ORDER BY plays DESC
LIMIT 50;
-- a title that loses half of the people before 10% has a bad thumbnail promise, not a bad ending

-- 2) binge: distribution of titles started per session, and the hours of the binge sessions
WITH per_session AS (
  SELECT
    session_key,
    ANY_VALUE(EXTRACT(HOUR FROM event_datetime_local)) AS hour_local,
    ANY_VALUE(EXTRACT(DAYOFWEEK FROM event_datetime_local)) AS weekday_local,
    COUNT(DISTINCT video_title) AS titles_started
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = play_event
  GROUP BY session_key
)
SELECT
  weekday_local,
  hour_local,
  COUNT(*) AS viewing_sessions,
  SAFE_DIVIDE(COUNTIF(titles_started >= 3), COUNT(*)) AS binge_share,
  AVG(titles_started) AS avg_titles_per_session
FROM per_session
GROUP BY 1, 2
ORDER BY 1, 2;
-- the binge hours are the hours for the "next episode" autoplay test and the push of new seasons

-- 3) the titles that sell the plan: last title watched in the 7 days before the first subscription
WITH subs AS (
  SELECT user_key, MIN(event_ts) AS subscribe_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND event_name IN UNNEST(subscribe_events)
  GROUP BY user_key
),
last_title AS (
  SELECT
    s.user_key,
    ARRAY_AGG(e.video_title ORDER BY e.event_ts DESC LIMIT 1)[OFFSET(0)] AS title
  FROM subs AS s
  JOIN `your-gcp-project.ga4_core.fct_events` AS e
    ON e.user_key = s.user_key
    AND e.event_ts BETWEEN TIMESTAMP_SUB(s.subscribe_ts, INTERVAL 7 DAY) AND s.subscribe_ts
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 97 DAY)
    AND e.event_name = play_event
    AND e.video_title IS NOT NULL
  GROUP BY s.user_key
),
viewers AS (
  SELECT video_title AS title, COUNT(DISTINCT user_key) AS viewers
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND event_name = play_event
  GROUP BY 1
)
SELECT
  l.title,
  COUNT(*) AS subscriptions_after_title,
  v.viewers,
  SAFE_DIVIDE(COUNT(*), v.viewers) AS subscriptions_per_viewer,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) AS share_of_subscriptions
FROM last_title AS l
JOIN viewers AS v USING (title)
GROUP BY l.title, v.viewers
ORDER BY subscriptions_after_title DESC
LIMIT 30;

-- 4) fading viewers: active subscribers whose weekly plays fell more than 60% vs their own last 4 weeks
-- (the churn shows in the player long before the cancel button)
WITH weekly AS (
  SELECT user_key, DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start, COUNT(*) AS plays
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 5 WEEK)
    AND event_date < DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
    AND event_name = play_event
  GROUP BY 1, 2
),
per_user AS (
  SELECT
    user_key,
    SUM(IF(week_start = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 WEEK), plays, 0)) AS plays_last_week,
    SUM(IF(week_start < DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 WEEK), plays, 0)) / 4 AS avg_plays_before
  FROM weekly
  GROUP BY 1
)
SELECT
  p.user_key,
  u.user_id,
  p.avg_plays_before,
  p.plays_last_week,
  SAFE_DIVIDE(p.plays_last_week, p.avg_plays_before) - 1 AS change,
  u.days_since_last_seen
FROM per_user AS p
JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
WHERE p.avg_plays_before >= 3
  AND SAFE_DIVIDE(p.plays_last_week, p.avg_plays_before) < 0.4
  AND u.is_identified
ORDER BY p.avg_plays_before DESC
LIMIT 500;
-- send to CRM with a "new on your list" message, respecting the consent (act_consent_eligible_users)
