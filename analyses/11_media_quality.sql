-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- media quality: where the money goes to bots, broken urls and lost attribution

-- 1) campaigns with grade C / D, the worst problem first
SELECT source, medium, campaign, sessions, grade, media_quality_score, main_problem,
       bot_share, attribution_loss_share, tagging_issue_share, engagement_rate_humans,
       cost, cost_on_bots, cost_per_engaged_human_session
FROM `your-gcp-project.ga4_marketing.mkt_media_quality_scorecard`
WHERE grade IN ('C', 'D')
ORDER BY COALESCE(cost_on_bots, 0) DESC, sessions DESC
LIMIT 50;

-- 2) the url problems to send to the agency (with an example url and the fix)
SELECT severity, issue, utm_source, utm_medium, utm_campaign, sessions_affected, revenue_affected,
       channel_it_went_to, example_url, how_to_fix
FROM `your-gcp-project.ga4_marketing.mkt_url_tagging_issues`
WHERE severity = 'high'
ORDER BY revenue_affected DESC, sessions_affected DESC;

-- 3) tagged sessions that GA4 did not attribute, last 30 days
SELECT utm_source, utm_medium, SUM(tagged_sessions) AS tagged, SUM(lost_sessions) AS lost,
       SAFE_DIVIDE(SUM(lost_sessions), SUM(tagged_sessions)) AS loss_share,
       SUM(sessions_without_source_medium_param) AS without_source_medium_param,
       SUM(sessions_ignored_by_ga4) AS ga4_said_direct,
       SUM(revenue_lost) AS revenue_lost
FROM `your-gcp-project.ga4_marketing.mkt_utm_attribution_loss_daily`
WHERE session_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 30 DAY)
GROUP BY 1, 2
HAVING SUM(tagged_sessions) >= 100
ORDER BY revenue_lost DESC;

-- 4) bot share by campaign, and the purchases inside "bot" sessions (false positive check)
SELECT channel, source_medium, campaign, SUM(sessions) AS sessions, SUM(bot_sessions) AS bot_sessions,
       SAFE_DIVIDE(SUM(bot_sessions), SUM(sessions)) AS bot_share,
       SUM(bot_sessions_with_purchase) AS bot_sessions_with_purchase
FROM `your-gcp-project.ga4_data_quality.dq_bot_traffic_daily`
WHERE session_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 30 DAY)
GROUP BY 1, 2, 3
HAVING SUM(sessions) >= 200
ORDER BY bot_share DESC
LIMIT 50;
