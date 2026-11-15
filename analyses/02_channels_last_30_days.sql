-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- channels of the last 30 days vs the 30 before, GA4 default channel group
-- (switch to session_custom_channel_group to see AI assistants, WhatsApp, brand search...)

WITH periods AS (
  SELECT
    session_default_channel_group AS channel,
    IF(session_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 30 DAY), 'last_30', 'previous_30') AS period,
    SUM(sessions) AS sessions,
    SUM(sessions_with_purchase) AS converting_sessions,
    SUM(transactions) AS transactions,
    SUM(revenue) AS revenue
  FROM `your-gcp-project.ga4_marketing.mkt_channel_daily`
  WHERE session_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 60 DAY)
    AND session_date < CURRENT_DATE('America/Sao_Paulo')
  GROUP BY 1, 2
)

SELECT
  channel,
  SUM(IF(period = 'last_30', sessions, 0)) AS sessions,
  SAFE_DIVIDE(SUM(IF(period = 'last_30', sessions, 0)), SUM(IF(period = 'previous_30', sessions, 0))) - 1 AS sessions_change,
  SUM(IF(period = 'last_30', revenue, 0)) AS revenue,
  SAFE_DIVIDE(SUM(IF(period = 'last_30', revenue, 0)), SUM(IF(period = 'previous_30', revenue, 0))) - 1 AS revenue_change,
  SAFE_DIVIDE(SUM(IF(period = 'last_30', converting_sessions, 0)), SUM(IF(period = 'last_30', sessions, 0))) AS conversion_rate,
  SAFE_DIVIDE(SUM(IF(period = 'last_30', revenue, 0)), SUM(IF(period = 'last_30', transactions, 0))) AS aov
FROM periods
GROUP BY channel
ORDER BY revenue DESC;

-- the same channels, but credited by every attribution model (look at the gap vs last non-direct)
SELECT *
FROM `your-gcp-project.ga4_attribution.attr_data_driven_summary`
ORDER BY consensus_conversions DESC;
