<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# Data contracts (core layer)

The marts, reports, data science and activation layers only read the tables below
(plus `dim_calendar` and the seeds). If you change a column here, check who uses it:
`grep -r "column_name" definitions/`.

Grain first, columns after. Types are the obvious ones (ids are STRING, flags BOOL, money FLOAT64).

---

## `ga4_core.fct_sessions`  (grain: 1 row per session_key)

| group | columns |
|---|---|
| keys / time | `session_key`, `session_date` (partition), `session_start_ts`, `session_end_ts`, `session_start_local`, `session_hour`, `session_iso_weekday` (1=mon), `session_week`, `session_month` |
| user | `user_pseudo_id`, `user_id`, `user_key`, `is_identified_user`, `session_number`, `is_session_number_fixed`, `is_new_user`, `platform`, `stream_id` |
| traffic (GA4 style, last non-direct) | `session_source`, `session_medium`, `session_campaign`, `session_campaign_id`, `session_term`, `session_content`, `session_source_medium`, `session_default_channel_group`, `session_custom_channel_group` |
| traffic (session only, no carry over) | `session_source_only`, `session_medium_only`, `session_channel_only`, `is_carried_over`, `carried_days_ago` |
| traffic fixes / audit | `traffic_fix_applied`, `excluded_referral_source`, `excluded_referral_reason`, `gclid`, `gbraid`, `wbraid`, `fbclid`, `msclkid`, `ttclid`, `srsltid`, `has_click_id`, `ga4_native_source`, `ga4_native_medium`, `ga4_native_campaign`, `ga4_native_default_channel_group`, `google_ads_campaign_id`, `google_ads_campaign_name`, `google_ads_ad_group_name`, `ga4_first_user_source`, `ga4_first_user_medium`, `ga4_first_user_campaign` |
| landing / exit | `landing_page_path`, `landing_page_path_ga4`, `landing_page_title`, `landing_page_location`, `landing_hostname`, `landing_page_type`, `is_landing_page_fixed`, `exit_page_path` |
| device / geo | `device_category`, `device_os`, `device_os_version`, `device_browser`, `device_browser_version`, `device_language`, `device_brand`, `device_model`, `app_version`, `hostname`, `geo_continent`, `geo_sub_continent`, `geo_country`, `geo_region`, `geo_city`, `geo_uf`, `geo_macro_region` |
| engagement | `event_count`, `page_views`, `screen_views`, `unique_pages`, `interaction_events`, `engagement_time_msec`, `engagement_time_sec`, `session_duration_sec`, `is_engaged`, `is_engaged_ga4`, `is_bounce_ga4`, `is_bounce_ua` |
| key events | `key_events`, `key_event_value`, `primary_key_events`, `has_key_event`, `key_event_names` (ARRAY) |
| ecommerce | `transactions`, `revenue`, `revenue_in_usd`, `items_purchased`, `has_purchase`, `used_coupon`, `has_view_item`, `has_add_to_cart`, `has_begin_checkout`, `has_add_shipping_info`, `has_add_payment_info`, `view_item_events`, `add_to_cart_events`, `cart_value`, `checkout_value`, `is_cart_abandoned`, `is_checkout_abandoned`, `has_payment_retries`, `has_site_search`, `has_promotion_click`, `last_payment_type`, `last_shipping_tier` |
| privacy | `consent_analytics_storage`, `consent_ads_storage` (granted / denied / unknown), `consent_changed_in_session` |
| quality | `bot_score` (max of session and device), `session_bot_score`, `device_bot_score`, `is_bot_device`, `bot_signals`, `is_bot_suspect` (session OR device), `has_session_start`, `is_non_production_host`, `data_quality_score`, `data_quality_issues`, `is_trusted_session` |

## `ga4_core.fct_transactions`  (grain: 1 row per transaction_id, deduplicated in all history)

`transaction_id`, `event_id`, `transaction_date` (partition), `transaction_ts`, `session_key`, `user_pseudo_id`, `user_id`, `user_key`,
`stream_id`, `platform`, `hostname`, `currency`, `revenue`, `revenue_source`, `revenue_in_usd`, `purchase_revenue_raw`, `value_param_raw`,
`items_revenue`, `shipping_value`, `tax_value`, `coupon`, `payment_type`, `shipping_tier`, `items_count`, `unique_items`, `item_quantity`,
`items` (ARRAY), `times_sent`, `is_missing_transaction_id`, `is_test_transaction`, `is_deferred_payment`, `is_negative_revenue`,
`is_zero_revenue`, `has_items_revenue_mismatch`, session context (`session_source`, `session_medium`, `session_campaign`,
`session_default_channel_group`, `session_custom_channel_group`, `landing_page_path`, `landing_page_type`, `device_category`,
`device_browser`, `geo_country`, `geo_region`, `geo_uf`, `geo_city`, `is_new_user`, `session_number`, `consent_ads_storage`, `is_bot_suspect`),
`refunded_value`, `first_refund_date`, `has_full_refund`, `net_revenue`, `revenue_robust_z`, `order_number`, `is_first_purchase`,
`days_since_previous_order`, `is_revenue_outlier`, `is_valid_for_revenue`.
With `enable_crm`: `crm_status`, `crm_order_value`, `crm_payment_method`, `crm_paid_ts`.

**Official revenue = `SUM(revenue) WHERE is_valid_for_revenue`.**

## `ga4_core.fct_transaction_items`  (grain: transaction x item line)

`transaction_id`, `transaction_date`, `transaction_ts`, `session_key`, `user_key`, `currency`, `order_coupon`, `payment_type`,
`session_default_channel_group`, `session_custom_channel_group`, `session_source`, `session_medium`, `session_campaign`,
`device_category`, `geo_uf`, `order_number`, `is_first_purchase`, `is_test_transaction`, `is_valid_for_revenue`, `item_position`,
`item_id`, `item_name`, `item_brand`, `item_variant`, `item_category`, `item_category2`, `item_category3`, `price`, `quantity`,
`item_revenue`, `item_coupon`, `item_list_name`, `affiliation`, `item_discount`, `item_share_of_order`, `lines_in_order`.

## `ga4_core.fct_key_events`  (grain: 1 counted key event occurrence)

`key_event_id`, `key_event_name`, `key_event_category`, `event_id`, `event_name`, `event_date` (partition), `event_ts`, `session_key`,
`user_pseudo_id`, `user_key`, `transaction_id`, `currency`, `key_event_value`, `counting_method`, `is_primary`, `session_date`,
`session_start_ts`, `seconds_into_session`, `session_number`, `is_new_user`, `session_source`, `session_medium`, `session_campaign`,
`session_source_medium`, `session_default_channel_group`, `session_custom_channel_group`, `landing_page_path`, `landing_page_type`,
`device_category`, `geo_country`, `geo_uf`, `consent_ads_storage`, `is_bot_suspect`.

## `ga4_core.fct_user_daily`  (grain: user_key x activity_date)

`user_key`, `activity_date` (partition), `sessions`, `engaged_sessions`, `views`, `engagement_time_sec`, `key_events`, `transactions`,
`revenue`, `added_to_cart`, `had_new_user_session`, `first_channel_of_day`, `first_device_of_day`, `device_categories`, `used_web`,
`used_app`, `first_seen_date`, `is_first_day`, `days_since_first_seen`, `days_since_previous_activity`.

## `ga4_core.fct_page_views`  (view, grain: 1 page_view / screen_view)

From `int_ga4__page_views`: `event_id`, `event_date`, `event_ts`, `event_name`, `session_key`, `user_pseudo_id`, `page_location`,
`page_path`, `page_title`, `page_hostname`, `page_referrer`, `content_group`, `page_number`, `session_view_count`, `is_entrance`,
`is_exit`, `previous_page_path`, `next_page_path`, `time_on_page_sec`, `seconds_since_previous_view`, `is_reload`,
`page_engagement_msec`, `max_percent_scrolled`, `reached_90_percent`, `interactions_on_page`, `events_on_page`.
Plus: `page_type`, `is_not_found_page`, `user_key`, `session_date`, `session_number`, `is_new_user`, `is_engaged_session`,
`session_has_purchase`, `session_has_key_event`, `session_revenue`, `landing_page_path`, `session_source`, `session_medium`,
`session_default_channel_group`, `session_custom_channel_group`, `device_category`, `device_browser`, `geo_country`, `geo_uf`, `is_bot_suspect`.

## `ga4_core.fct_item_interactions`  (view, grain: event x item)

All `stg_ga4__event_items` columns (`event_date`, `event_id`, `event_ts`, `event_name`, `session_key`, `item_id`, `item_name`,
`item_brand`, `item_category`..`item_category5`, `price`, `quantity`, `item_revenue_fixed`, `item_value`, `item_coupon`,
`item_list_name`, `item_list_index`, `promotion_id`, `promotion_name`, `creative_name`, `creative_slot`, `item_discount`...)
plus session context: `user_key`, `is_new_user`, `session_source`, `session_medium`, `session_campaign`,
`session_default_channel_group`, `session_custom_channel_group`, `landing_page_type`, `device_category`, `geo_uf`,
`session_has_purchase`, `is_bot_suspect`.

## `ga4_core.dim_users`  (grain: user_key)

`user_key`, `user_id`, `is_identified`, `last_user_pseudo_id`, `devices`, `device_categories`, `first_seen_ts`, `last_seen_ts`,
`first_seen_date`, `last_seen_date`, `days_since_last_seen`, `active_span_days`, `sessions`, `engaged_sessions`, `views`,
`engagement_time_sec`, `key_events`, `sessions_with_cart`, `sessions_with_checkout`, `sessions_with_search`, `distinct_channels`,
`first_channel`, `first_custom_channel`, `first_source`, `first_medium`, `first_campaign`, `first_landing_page`,
`first_landing_page_type`, `first_device_category`, `first_country`, `first_uf`, `ga4_first_user_source`, `ga4_first_user_medium`,
`ga4_first_user_campaign`, `last_channel`, `last_device_category`, `last_uf`, `last_city`, `main_channel`, `main_device`,
`transactions`, `lifetime_revenue`, `lifetime_net_revenue`, `first_purchase_date`, `last_purchase_date`, `avg_order_value`,
`coupon_orders`, `avg_days_between_orders`, `is_customer`, `is_repeat_customer`, `days_since_last_purchase`,
`days_to_first_purchase`, `latest_consent_ads`, `latest_consent_analytics`, `user_properties` (ARRAY).

## other dimensions

- `dim_items` (item_id): names/brand/categories, `category_path`, `name_variants`, `current_price`, lifetime funnel numbers.
- `dim_pages` (page_path): `page_title`, `page_type`, `is_not_found`, `path_level_1..4`, `path_depth`, lifetime views/entrances/exits.
- `dim_traffic_sources` (source/medium): channel groups, `source_category`, `is_ai_assistant`, lifetime numbers.
- `dim_campaigns` (campaign/source/medium): `ad_platform`, `is_brand_campaign`, ids, lifetime numbers.
- `dim_user_identity` (user_pseudo_id): `user_key`, `user_id`, `identity_method` (login / linked_by_transaction / linked_by_click_id / merged_anonymous / device_only), `is_identified`, `is_identified_by_login`, `is_shared_device`, `devices_of_user`, `had_ignored_user_id`.
- `dim_calendar` (date_day): brazilian holidays, retail events, `same_weekday_last_year`, business days, salary window, `is_special_day`.
- `fct_ad_costs_daily` (date x platform x campaign): `cost`, `clicks`, `impressions`, `cpc`, `cpm`, `ctr`.

## rules everybody follows

1. Bots: core keeps them (`is_bot_suspect`). Business marts filter with `helpers.martSessionFilter()`.
   GA4 / UA replica reports keep them, so the numbers match the GA4 UI.
2. Users across days: never `SUM(users)`. Daily tables carry `users_hll` (HLL sketch), use `HLL_COUNT.MERGE(users_hll)`.
3. Revenue: `fct_transactions.is_valid_for_revenue`. Session revenue (`fct_sessions.revenue`) already excludes tests.
4. Dates are always in the property timezone (`property_timezone`). Timestamps are UTC.
