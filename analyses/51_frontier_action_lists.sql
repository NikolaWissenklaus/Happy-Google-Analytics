-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the weekly action lists from the frontier models (tag frontier, docs/frontier.md)
-- each query is one decision for one team. Run after `dataform run --tags frontier`.

-- 1) CRM: people waiting for a price drop, hot, with consent. Send THIS product to THIS person
SELECT user_key, item_name, view_days, first_seen_price, current_price, price_change_since_first_view, item_watchers
FROM `your-gcp-project.ga4_segments.seg_price_watchers`
WHERE watch_status = 'hot' AND consent_ads_storage = 'granted'
ORDER BY view_days DESC, item_watchers DESC
LIMIT 500;

-- 2) PRICING: products losing to the competitor (they leave to compare and never come back)
SELECT item_name, item_category, median_price, departures, never_returned_share, category_never_returned_share,
       competitor_loss_index, returned_via_search_share
FROM `your-gcp-project.ga4_ecommerce.ecom_price_check_departures`
WHERE verdict = 'losing_outside'
ORDER BY departures * never_returned_share DESC
LIMIT 50;

-- 3) PURCHASING / STOCK: the sizes and colours people hunt and do not find
SELECT item_name, hunting_rate, gave_up_hunters, estimated_revenue_lost, dead_end_variants
FROM `your-gcp-project.ga4_ecommerce.ecom_variant_hunting`
ORDER BY estimated_revenue_lost DESC
LIMIT 30;

-- 4) MERCHANDISING: the shelf "faltam R$ X para o frete gratis"
SELECT threshold, item_name, median_price, filler_adds, avg_overshoot, filler_session_conversion
FROM `your-gcp-project.ga4_ecommerce.ecom_cart_filler_items`
QUALIFY ROW_NUMBER() OVER (PARTITION BY threshold ORDER BY filler_adds DESC) <= 10
ORDER BY threshold, filler_adds DESC;

-- 5) PRODUCT: items people regret at the cart (and if the freight is the reason)
SELECT item_name, carts, removal_rate, regret_index, regret_style, freight_regret_share
FROM `your-gcp-project.ga4_ecommerce.ecom_cart_indecision`
WHERE regret_index >= 1.3
ORDER BY carts * removal_rate DESC
LIMIT 30;

-- 6) FINANCE: revenue already in the pipeline of open carts for the next 7 days
SELECT
  ANY_VALUE(total_expected_orders) AS expected_orders_next_7d,
  ANY_VALUE(total_expected_revenue) AS expected_revenue_next_7d,
  SUM(open_carts_now) AS open_carts,
  ANY_VALUE(pipeline_pressure) AS pipeline_pressure
FROM `your-gcp-project.ga4_ecommerce.ecom_cart_pipeline_forecast`;

-- 7) UX: the cliffs of the visit (a page number or a minute where people die too much)
SELECT device_category, curve, step, sessions_alive, hazard, hazard_excess
FROM `your-gcp-project.ga4_product.prod_session_hazard_curve`
WHERE is_cliff
ORDER BY hazard_excess DESC;

-- 8) CATALOGUE / CATEGORY: the shelf size that converts best per category
SELECT main_category, sweet_spot_items, overload_share, overload_conversion_gap
FROM `your-gcp-project.ga4_ecommerce.ecom_choice_overload`
WHERE is_sweet_spot
ORDER BY overload_share DESC;

-- 9) MEDIA: the campaigns that bring the richest (and the poorest) audiences
SELECT grouping_value AS campaign, sessions, affluence_index, premium_share, entry_share, revenue_per_session_ratio
FROM `your-gcp-project.ga4_marketing.mkt_audience_affluence_index`
WHERE grouping_level = 'campaign'
ORDER BY affluence_index DESC;

-- 10) BOARD: how hostage the revenue is to one company
SELECT week, lens, effective_players, top_player, top_share, revenue_at_risk_top
FROM `your-gcp-project.ga4_business.biz_channel_dependency_risk`
ORDER BY week DESC, lens
LIMIT 8;

-- 11) GROWTH: the K factor of word of mouth over the last weeks
SELECT week, active_users, sharers, shares, new_users_from_shared_links, k_factor, referred_conversion_rate, baseline_new_user_conversion_rate
FROM `your-gcp-project.ga4_marketing.mkt_viral_coefficient`
WHERE NOT is_incomplete_week
ORDER BY week DESC;

-- 12) read 20 sessions that abandoned the checkout yesterday, as text (or feed them to an LLM)
SELECT narrative
FROM `your-gcp-project.ga4_data_science.ds_session_narratives`
WHERE session_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND outcome = 'abandoned_checkout'
  AND NOT is_bot_suspect
LIMIT 20;
