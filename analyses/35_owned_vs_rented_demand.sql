-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- how much of the revenue is OWNED demand (people that already know the brand and come by
-- themselves) and how much is RENTED every month from Google and Meta?
-- owned demand is the real brand equity: it is what stays when the media budget stops. Growing
-- owned demand is the goal of branding, content and CRM.

SELECT
  DATE_TRUNC(transaction_date, MONTH) AS month,
  SUM(revenue) AS revenue,
  SAFE_DIVIDE(SUM(IF(demand_type = 'owned', revenue, 0)), SUM(revenue)) AS owned_share,
  SAFE_DIVIDE(SUM(IF(demand_type = 'brand_search', revenue, 0)), SUM(revenue)) AS brand_search_share,
  SAFE_DIVIDE(SUM(IF(demand_type = 'rented_paid', revenue, 0)), SUM(revenue)) AS rented_paid_share,
  SAFE_DIVIDE(SUM(IF(demand_type = 'earned', revenue, 0)), SUM(revenue)) AS earned_share
FROM (
  SELECT
    transaction_date,
    revenue,
    CASE
      WHEN session_default_channel_group IN ('Direct', 'Email', 'SMS', 'Mobile Push Notifications') THEN 'owned'
      -- brand campaigns / brand terms (custom channel group with the brand rules of cfg_channels.js)
      WHEN LOWER(COALESCE(session_custom_channel_group, '')) LIKE '%brand%'
        AND LOWER(COALESCE(session_custom_channel_group, '')) NOT LIKE '%non%' THEN 'brand_search'
      WHEN REGEXP_CONTAINS(COALESCE(session_default_channel_group, ''), r'^(Paid|Display|Cross-network|Audio|Video)') THEN 'rented_paid'
      ELSE 'earned'
    END AS demand_type
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 24 MONTH)
)
GROUP BY month
ORDER BY month;

-- returning customers that came back through PAID media: the store pays again for people it
-- already had. These users should be excluded from prospecting and reached by CRM instead
SELECT
  DATE_TRUNC(transaction_date, MONTH) AS month,
  COUNTIF(NOT is_first_purchase AND REGEXP_CONTAINS(COALESCE(session_default_channel_group, ''), r'^(Paid|Display|Cross-network)')) AS repeat_orders_via_paid,
  SUM(IF(NOT is_first_purchase AND REGEXP_CONTAINS(COALESCE(session_default_channel_group, ''), r'^(Paid|Display|Cross-network)'), revenue, 0)) AS repeat_revenue_via_paid,
  SAFE_DIVIDE(
    COUNTIF(NOT is_first_purchase AND REGEXP_CONTAINS(COALESCE(session_default_channel_group, ''), r'^(Paid|Display|Cross-network)')),
    COUNTIF(REGEXP_CONTAINS(COALESCE(session_default_channel_group, ''), r'^(Paid|Display|Cross-network)'))
  ) AS share_of_paid_orders_from_existing_customers
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
GROUP BY month
ORDER BY month;

-- concentration by channel and by the company behind the traffic (frontier):
SELECT week, lens, effective_players, top_player, top_share, hhi_vs_8_week_avg
FROM `your-gcp-project.ga4_business.biz_channel_dependency_risk`
WHERE lens = 'traffic_owner'
ORDER BY week DESC
LIMIT 12;
