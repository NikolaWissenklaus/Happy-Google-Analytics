-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- HOW TO READ the GA4 UI replicas of the extras pack (ga4_reports.*), the same way the UI does.
-- Rule number one again: users of a period = HLL_COUNT.MERGE of the *_hll column, never SUM(users).

-- 1) Monetization > Overview cards, last 28 days (purchasers merged with HLL)
SELECT
  SUM(total_revenue) AS total_revenue,
  SUM(purchase_revenue) AS purchase_revenue,
  SUM(valid_purchase_revenue) AS valid_purchase_revenue,
  HLL_COUNT.MERGE(purchasers_hll) AS total_purchasers,
  SUM(first_time_purchasers) AS first_time_purchasers,
  HLL_COUNT.MERGE(active_users_hll) AS active_users,
  SAFE_DIVIDE(SUM(total_revenue), HLL_COUNT.MERGE(active_users_hll)) AS arpu,
  SAFE_DIVIDE(SUM(total_revenue), HLL_COUNT.MERGE(purchasers_hll)) AS arppu,
  SAFE_DIVIDE(SUM(purchase_revenue), SUM(ecommerce_purchases)) AS average_purchase_revenue
FROM `your-gcp-project.ga4_reports.rpt_ga4_monetization_overview_daily`
WHERE metric_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- 2) Advertising > All channels, last 28 days: ROAS and cost per key event per channel
SELECT
  default_channel_group,
  SUM(sessions) AS sessions,
  SUM(key_events) AS key_events,
  SUM(total_revenue) AS total_revenue,
  SUM(ads_cost) AS ads_cost,
  SAFE_DIVIDE(SUM(total_revenue), SUM(ads_cost)) AS return_on_ad_spend,
  SAFE_DIVIDE(SUM(ads_cost), SUM(key_events)) AS cost_per_key_event,
  SAFE_DIVIDE(SUM(sessions), SUM(ads_clicks)) AS sessions_per_ad_click
FROM `your-gcp-project.ga4_reports.rpt_ga4_advertising_all_channels_daily`
WHERE metric_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
GROUP BY 1
ORDER BY ads_cost DESC, sessions DESC;
-- a channel with cost and sessions_per_ad_click < 0.6: clicks that never become sessions (tagging, bots, slow page)

-- 3) User acquisition cohort as the GA4 grid: rows = cohort month x channel, columns = month 0..3
SELECT
  cohort_month,
  first_user_default_channel_group,
  MAX(new_users) AS new_users,
  MAX(IF(month_number = 1, retention_rate, NULL)) AS retention_m1,
  MAX(IF(month_number = 2, retention_rate, NULL)) AS retention_m2,
  MAX(IF(month_number = 3, retention_rate, NULL)) AS retention_m3,
  MAX(IF(month_number = 0, cumulative_revenue_per_user, NULL)) AS ltv_m0,
  MAX(IF(month_number = 3, cumulative_revenue_per_user, NULL)) AS ltv_m3
FROM `your-gcp-project.ga4_reports.rpt_ga4_user_acquisition_cohort`
GROUP BY 1, 2
HAVING MAX(new_users) >= 200
ORDER BY 1 DESC, new_users DESC;

-- 4) Generate leads: the lead funnel per first user channel, last 90 days
SELECT
  first_user_default_channel_group,
  HLL_COUNT.MERGE(IF(lead_stage = 'generate', users_hll, NULL)) AS users_generated,
  HLL_COUNT.MERGE(IF(lead_stage = 'qualify', users_hll, NULL)) AS users_qualified,
  HLL_COUNT.MERGE(IF(lead_stage = 'close_convert', users_hll, NULL)) AS users_converted,
  SAFE_DIVIDE(HLL_COUNT.MERGE(IF(lead_stage = 'close_convert', users_hll, NULL)), HLL_COUNT.MERGE(IF(lead_stage = 'generate', users_hll, NULL))) AS lead_to_customer
FROM `your-gcp-project.ga4_reports.rpt_ga4_lead_generation_daily`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY 1
ORDER BY users_generated DESC;

-- and why leads are lost (Lead disqualification and conversion report)
SELECT lead_stage, reason, SUM(event_count) AS events, SAFE_DIVIDE(SUM(event_count), SUM(SUM(event_count)) OVER (PARTITION BY lead_stage)) AS share
FROM `your-gcp-project.ga4_reports.rpt_ga4_lead_generation_daily`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND lead_stage IN ('disqualify', 'close_unconvert')
GROUP BY 1, 2
ORDER BY 1, events DESC;

-- 5) Enhanced measurement: the outbound domains that take people away, the most downloaded files,
-- the forms that are started and not submitted (last 28 days)
SELECT report, object_name, detail, SUM(event_count) AS events, HLL_COUNT.MERGE(users_hll) AS users
FROM `your-gcp-project.ga4_reports.rpt_ga4_enhanced_measurement_daily`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
  AND report IN ('outbound_click', 'file_download')
GROUP BY 1, 2, 3
QUALIFY ROW_NUMBER() OVER (PARTITION BY report ORDER BY SUM(event_count) DESC) <= 15
ORDER BY report, events DESC;

SELECT
  object_name AS form,
  SUM(IF(event_name = 'form_start', event_count, 0)) AS starts,
  SUM(IF(event_name = 'form_submit', event_count, 0)) AS submits,
  SAFE_DIVIDE(SUM(IF(event_name = 'form_submit', event_count, 0)), SUM(IF(event_name = 'form_start', event_count, 0))) AS completion
FROM `your-gcp-project.ga4_reports.rpt_ga4_enhanced_measurement_daily`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
  AND report = 'form'
GROUP BY 1
HAVING starts >= 50
ORDER BY completion;

-- 6) Ecommerce purchases by item category, last 28 days vs the 28 before
SELECT
  item_category,
  SUM(IF(event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY), item_revenue, 0)) AS revenue_28d,
  SUM(IF(event_date < DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY), item_revenue, 0)) AS revenue_prev_28d,
  SAFE_DIVIDE(
    SUM(IF(event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY), items_purchased, 0)),
    SUM(IF(event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY), items_viewed, 0))
  ) AS purchase_to_view_rate_28d,
  SAFE_DIVIDE(
    SUM(IF(event_date < DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY), items_purchased, 0)),
    SUM(IF(event_date < DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY), items_viewed, 0))
  ) AS purchase_to_view_rate_prev_28d
FROM `your-gcp-project.ga4_reports.rpt_ga4_item_categories_daily`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 56 DAY)
  AND event_date < CURRENT_DATE()
GROUP BY 1
ORDER BY revenue_28d DESC;

-- 7) the value of a relationship: revenue per session by session number band (rpt_ga4_new_established_daily)
SELECT
  session_number_band,
  SUM(sessions) AS sessions,
  SAFE_DIVIDE(SUM(engaged_sessions), SUM(sessions)) AS engagement_rate,
  SAFE_DIVIDE(SUM(ecommerce_purchases), SUM(sessions)) AS purchases_per_session,
  SAFE_DIVIDE(SUM(total_revenue), SUM(sessions)) AS revenue_per_session
FROM `your-gcp-project.ga4_reports.rpt_ga4_new_established_daily`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY 1
ORDER BY 1;

-- 8) the cheap android where the checkout breaks (Tech > device model)
SELECT
  mobile_device_branding,
  mobile_device_model,
  SUM(sessions) AS sessions,
  SAFE_DIVIDE(SUM(ecommerce_purchases), SUM(sessions)) AS purchases_per_session,
  SAFE_DIVIDE(SUM(engaged_sessions), SUM(sessions)) AS engagement_rate
FROM `your-gcp-project.ga4_reports.rpt_ga4_device_models_daily`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND device_category = 'mobile'
GROUP BY 1, 2
HAVING SUM(sessions) >= 500
ORDER BY purchases_per_session
LIMIT 20;
