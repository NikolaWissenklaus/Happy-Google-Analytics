-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- "average engagement time went up 20%!" ... or 50 tabs were left open on a monday.
-- prod_session_distribution_daily keeps percentiles per day, device and channel.

-- 1) the last 14 days: mean next to the median. A mean_to_median_ratio jumping alone is not a better experience
SELECT session_date, sessions, engagement_mean_sec, engagement_p50_sec, engagement_p90_sec, mean_to_median_ratio, zero_engagement_share
FROM `your-gcp-project.ga4_product.prod_session_distribution_daily`
WHERE device_category = '(all)' AND session_default_channel_group = '(all)'
  AND session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
ORDER BY session_date;

-- 2) this week vs last week, by device: did the TYPICAL session change? (medians of the daily medians)
SELECT
  device_category,
  APPROX_QUANTILES(IF(session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), engagement_p50_sec, NULL), 2 IGNORE NULLS)[OFFSET(1)] AS median_this_week,
  APPROX_QUANTILES(IF(session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), engagement_p50_sec, NULL), 2 IGNORE NULLS)[OFFSET(1)] AS median_last_week,
  AVG(IF(session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), single_view_share, NULL)) AS single_view_share_this_week,
  AVG(IF(session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), single_view_share, NULL)) AS single_view_share_last_week
FROM `your-gcp-project.ga4_product.prod_session_distribution_daily`
WHERE session_default_channel_group = '(all)'
  AND session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
  AND session_date < CURRENT_DATE()
GROUP BY 1
ORDER BY 1;

-- 3) channels whose sessions are "empty" (0 seconds of engagement): bots, broken landing pages or consent problems
SELECT session_default_channel_group, SUM(sessions) AS sessions,
  SUM(zero_engagement_share * sessions) / SUM(sessions) AS zero_engagement_share,
  SUM(single_view_share * sessions) / SUM(sessions) AS single_view_share
FROM `your-gcp-project.ga4_product.prod_session_distribution_daily`
WHERE device_category = '(all)' AND session_default_channel_group != '(all)'
  AND session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
GROUP BY 1
HAVING SUM(sessions) >= 500
ORDER BY zero_engagement_share DESC;

-- 4) the shape of a typical day, for the presentation: p10 / p25 / p50 / p75 / p90 of engagement per device
SELECT device_category, engagement_p10_sec, engagement_p25_sec, engagement_p50_sec, engagement_p75_sec, engagement_p90_sec, engagement_p99_sec
FROM `your-gcp-project.ga4_product.prod_session_distribution_daily`
WHERE session_default_channel_group = '(all)'
  AND session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
ORDER BY device_category;
