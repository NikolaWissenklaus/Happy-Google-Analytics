-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- "the site went crazy yesterday at 21h, what was it?". Every burst of visits with the probable
-- cause: CRM blast, TV / influencer (direct and brand search with no campaign), paid, bots.

SELECT
  burst_start_local,
  channel,
  probable_cause,
  burst_minutes,
  ROUND(baseline_sessions_per_minute, 1) AS normal_sessions_per_minute,
  peak_sessions_per_minute,
  ROUND(incremental_sessions) AS extra_sessions,
  minutes_to_half_peak,
  ROUND(bot_share, 2) AS bot_share,
  transactions,
  revenue,
  top_source_medium,
  top_campaign,
  top_landing_page
FROM `your-gcp-project.ga4_marketing.mkt_traffic_bursts`
WHERE burst_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 7 DAY)
ORDER BY incremental_sessions DESC
LIMIT 50;

-- and the opposite: minutes where the site (or the tag) went silent
SELECT blackout_start_local, blackout_end_local, platform, silent_minutes, ROUND(expected_events) AS expected_events,
  chance_probability, ROUND(estimated_lost_revenue, 2) AS estimated_lost_revenue, severity
FROM `your-gcp-project.ga4_data_quality.dq_tracking_blackouts`
ORDER BY blackout_start_local DESC;

-- how big the peaks are, for the infra team (last 30 days)
SELECT event_date, peak_minute_local, peak_concurrent_sessions, peak_views_per_second, ROUND(peak_to_median_ratio, 1) AS peak_to_median_ratio
FROM `your-gcp-project.ga4_product.prod_traffic_load_profile`
WHERE event_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 30 DAY)
ORDER BY peak_concurrent_sessions DESC
LIMIT 10;
