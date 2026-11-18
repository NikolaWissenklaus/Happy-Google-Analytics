-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- which campaigns pay for themselves, for real?
-- cost of fct_ad_costs_daily (Google Ads, Meta and manual costs) against the GA4 sessions of the
-- same campaign name: revenue, NEW customers, net revenue, bots and the campaigns spending with
-- no order at all. Campaign names are matched in lower case: keep the utm_campaign = campaign name.
-- Last 30 days.

WITH costs AS (
  SELECT LOWER(campaign) AS campaign, ANY_VALUE(platform) AS platform,
         SUM(cost) AS cost, SUM(clicks) AS clicks, SUM(impressions) AS impressions
  FROM `your-gcp-project.ga4_core.fct_ad_costs_daily`
  WHERE cost_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND cost_date < CURRENT_DATE()
  GROUP BY 1
),
sessions AS (
  SELECT
    LOWER(session_campaign) AS campaign,
    COUNT(*) AS sessions,
    SAFE_DIVIDE(COUNTIF(is_bot_suspect), COUNT(*)) AS bot_share,
    SAFE_DIVIDE(COUNTIF(is_engaged AND NOT is_bot_suspect), COUNTIF(NOT is_bot_suspect)) AS engagement_rate,
    SUM(IF(NOT is_bot_suspect, transactions, 0)) AS orders,
    SUM(IF(NOT is_bot_suspect, revenue, 0)) AS revenue
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND session_date < CURRENT_DATE()
  GROUP BY 1
),
orders AS (
  SELECT LOWER(session_campaign) AS campaign,
         COUNTIF(is_first_purchase) AS new_customers,
         SUM(net_revenue) AS net_revenue
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue
    AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND transaction_date < CURRENT_DATE()
  GROUP BY 1
)
SELECT
  c.platform,
  c.campaign,
  c.cost,
  c.clicks,
  s.sessions,
  -- clicks that never became a session: tag missing, redirect breaking the utms, or click fraud
  SAFE_DIVIDE(s.sessions, c.clicks) AS sessions_per_click,
  s.bot_share,
  s.engagement_rate,
  COALESCE(s.orders, 0) AS orders,
  COALESCE(s.revenue, 0) AS revenue,
  COALESCE(o.net_revenue, 0) AS net_revenue,
  COALESCE(o.new_customers, 0) AS new_customers,
  SAFE_DIVIDE(s.revenue, c.cost) AS roas_last_non_direct,
  SAFE_DIVIDE(o.net_revenue, c.cost) AS net_roas,
  SAFE_DIVIDE(c.cost, o.new_customers) AS cost_per_new_customer,
  CASE
    WHEN s.sessions IS NULL THEN 'cost_without_sessions (check the utm_campaign)'
    WHEN COALESCE(s.orders, 0) = 0 AND c.cost > 500 THEN 'spending_without_orders'
    WHEN s.bot_share > 0.2 THEN 'bot_heavy'
    WHEN SAFE_DIVIDE(o.net_revenue, c.cost) < 1 THEN 'below_break_even'
    ELSE 'ok'
  END AS flag
FROM costs AS c
LEFT JOIN sessions AS s USING (campaign)
LEFT JOIN orders AS o USING (campaign)
ORDER BY c.cost DESC;

-- campaigns get very different credit by model (last click undervalues prospecting):
-- ga4_attribution.attr_campaign_by_model and the consensus of every model in attr_model_consensus
