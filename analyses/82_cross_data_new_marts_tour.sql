-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- THE CROSS DATA MARTS of the extras pack (cfg_extras.js), one question each.
-- Run after the daily run. Every query reads one mart, ready to paste in the weekly meeting.

-- 1) calendar x media: on which special days the money works better (or worse) than a normal day
SELECT platform, day_type, days, cost, roas, roas_index, cpc_index, conversion_rate_index, verdict
FROM `your-gcp-project.ga4_marketing.mkt_calendar_media_efficiency`
WHERE day_type != 'normal weekday' AND days >= 2
ORDER BY ABS(roas_index - 1) DESC
LIMIT 20;

-- 2) launches that only moved money from one product to the other (and the ones that created money)
SELECT item_name, item_category, first_seen_date, launch_revenue, cannibalized_revenue, incremental_revenue,
  cannibalization_rate, store_trend, other_launches_same_category, verdict
FROM `your-gcp-project.ga4_ecommerce.ecom_launch_cannibalization`
ORDER BY cannibalized_revenue DESC
LIMIT 20;

-- the whole picture: of every real the launches made, how much was really new?
SELECT
  SUM(launch_revenue) AS launch_revenue,
  SUM(incremental_revenue) AS incremental_revenue,
  SAFE_DIVIDE(SUM(incremental_revenue), SUM(launch_revenue)) AS share_really_new
FROM `your-gcp-project.ga4_ecommerce.ecom_launch_cannibalization`;

-- 3) the wishlist backlog: money waiting in open wishlists, with the action per product
SELECT action, COUNT(*) AS products, SUM(open_wishlists) AS open_wishlists, SUM(expected_revenue_open_wishlists) AS expected_revenue
FROM `your-gcp-project.ga4_ecommerce.ecom_wishlist_to_purchase`
GROUP BY 1
ORDER BY expected_revenue DESC;

SELECT item_name, wishlist_adds, open_wishlists, wishlist_conversion_rate, substitute_rate,
  median_days_to_buy, price_change_since_add, action
FROM `your-gcp-project.ga4_ecommerce.ecom_wishlist_to_purchase`
WHERE action != 'nothing to do'
ORDER BY expected_revenue_open_wishlists DESC
LIMIT 30;

-- 4) what each state buys more than Brazil (regional banners, regional campaigns, DC stock)
SELECT geo_uf, item_category, units, location_quotient, z_score, top_item_name
FROM `your-gcp-project.ga4_ecommerce.ecom_regional_bestsellers`
WHERE signal = 'over_index'
QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_uf ORDER BY location_quotient DESC) <= 3
ORDER BY geo_uf, location_quotient DESC;

-- 5) the next special days with last year's numbers (the planning meeting agenda)
SELECT
  event_name, event_date, days_until_event, prep_start_date,
  ROUND(event_day_index, 2) AS event_day_index,
  ROUND(warm_up_index, 2) AS warm_up_index,
  ROUND(hangover_index, 2) AS hangover_index,
  estimated_event_day_revenue,
  (SELECT STRING_AGG(c.channel, ', ' ORDER BY c.revenue DESC) FROM UNNEST(top_channels) AS c) AS channels_that_carried_it,
  (SELECT STRING_AGG(c.item_category, ', ' ORDER BY c.revenue DESC) FROM UNNEST(top_categories) AS c) AS categories_that_sold,
  playbook
FROM `your-gcp-project.ga4_business.biz_upcoming_events_playbook`
ORDER BY event_date;

-- 6) the department that makes the best customers (what to advertise for acquisition)
SELECT first_category, customers, avg_first_order_value, repeat_rate_90d, revenue_per_customer_180d,
  cross_category_share, ltv_index, verdict
FROM `your-gcp-project.ga4_ecommerce.ecom_first_category_ltv`
WHERE customers_mature_180d >= 30
ORDER BY ltv_index DESC;

-- 7) brand paid search: incremental or cannibal?
SELECT
  ANY_VALUE(incrementality_slope) AS incrementality_slope,
  ANY_VALUE(corr_paid_vs_organic) AS corr_paid_vs_organic,
  SUM(paid_brand_cost) AS brand_cost_52w,
  SUM(paid_brand_cost) * (1 - LEAST(GREATEST(ANY_VALUE(incrementality_slope), 0), 1)) AS cost_buying_free_clicks_estimate,
  ANY_VALUE(verdict) AS verdict
FROM `your-gcp-project.ga4_marketing.mkt_brand_paid_organic_cannibalization`;

-- 8) the value of a login, per month (business case of app, login and loyalty program)
SELECT
  month_start,
  SUM(identified_sessions) / SUM(sessions) AS identified_session_share,
  SUM(identified_revenue) / NULLIF(SUM(identified_revenue) + SUM(anonymous_revenue), 0) AS identified_revenue_share,
  SAFE_DIVIDE(SUM(identified_revenue) / NULLIF(SUM(identified_sessions), 0), SUM(anonymous_revenue) / NULLIF(SUM(anonymous_sessions), 0)) AS value_gap,
  SUM(revenue_per_extra_identified_point) AS revenue_per_extra_identified_point
FROM `your-gcp-project.ga4_business.biz_identified_vs_anonymous_value`
GROUP BY 1
ORDER BY 1;
