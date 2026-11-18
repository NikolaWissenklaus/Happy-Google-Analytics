-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: publishers, news, blogs, recipe / review sites (revenue = ads, subscriptions, affiliates)
-- the business is attention: articles that are READ (not only opened), that make people read the
-- next one (recirculation), and audiences that come back. Set your RPM (revenue per 1000 views).

DECLARE rpm FLOAT64 DEFAULT 25.0;

-- 1) the real performance of each article: read rate, depth, recirculation, estimated ad revenue
SELECT
  page_path,
  ANY_VALUE(page_title) AS title,
  COUNT(*) AS views,
  COUNT(DISTINCT user_key) AS readers,
  SAFE_DIVIDE(COUNTIF(reached_90_percent), COUNT(*)) AS read_to_end_rate,
  APPROX_QUANTILES(time_on_page_sec, 100 IGNORE NULLS)[OFFSET(50)] AS median_seconds,
  -- recirculation: the reader went to another page of the site after this one
  SAFE_DIVIDE(COUNTIF(NOT is_exit), COUNT(*)) AS recirculation_rate,
  SAFE_DIVIDE(COUNTIF(is_entrance), COUNT(*)) AS entrance_share,
  COUNT(*) / 1000 * rpm AS estimated_ad_revenue,
  -- views generated AFTER this article in the same session (the article as a door)
  SUM(IF(NOT is_exit, session_view_count - page_number, 0)) AS downstream_views
FROM `your-gcp-project.ga4_core.fct_page_views`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND NOT is_bot_suspect
GROUP BY page_path
HAVING COUNT(*) >= 200
ORDER BY views DESC
LIMIT 200;

-- 2) audience loyalty: share of readers by visit frequency in the last 28 days (fly-by, casual, loyal)
SELECT
  CASE WHEN active_days = 1 THEN '1_fly_by' WHEN active_days <= 4 THEN '2_casual' WHEN active_days <= 11 THEN '3_regular' ELSE '4_loyal' END AS reader_type,
  COUNT(*) AS readers,
  SUM(views) AS views,
  SAFE_DIVIDE(SUM(views), SUM(SUM(views)) OVER ()) AS share_of_views
FROM (
  SELECT user_key, COUNT(*) AS active_days, SUM(views) AS views
  FROM `your-gcp-project.ga4_core.fct_user_daily`
  WHERE activity_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
  GROUP BY user_key
)
GROUP BY 1
ORDER BY 1;

-- 3) traffic sources by quality of attention: views per session and read rate per channel
-- (Discover and social bring volume, newsletter and direct bring readers)
SELECT
  session_default_channel_group AS channel,
  COUNT(DISTINCT session_key) AS sessions,
  SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT session_key)) AS views_per_session,
  SAFE_DIVIDE(COUNTIF(reached_90_percent), COUNT(*)) AS read_to_end_rate,
  COUNT(*) / 1000 * rpm AS estimated_ad_revenue
FROM `your-gcp-project.ga4_core.fct_page_views`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND NOT is_bot_suspect
GROUP BY 1
ORDER BY sessions DESC;

-- 4) the half life of an article: views by days since its first view (evergreen vs news)
WITH first_seen AS (
  SELECT page_path, MIN(event_date) AS first_date
  FROM `your-gcp-project.ga4_core.fct_page_views`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY page_path
  HAVING MIN(event_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 150 DAY)
)
SELECT
  LEAST(DATE_DIFF(v.event_date, f.first_date, DAY), 60) AS days_since_publish,
  COUNT(*) AS views,
  COUNT(DISTINCT v.page_path) AS articles
FROM `your-gcp-project.ga4_core.fct_page_views` AS v
JOIN first_seen AS f USING (page_path)
WHERE v.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
GROUP BY 1
ORDER BY 1;

-- content decay for SEO: ga4_seo.seo_content_decay. Content engagement: ga4_product.prod_content_engagement
