<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# report mapping

"Where is report X?" Here. GA4 replicas keep the GA4 rules (bots kept, GA4 channel grouping,
GA4 engagement), so the numbers are close to the UI. They will never be identical: the UI uses
thresholds, modeling for consent denied users, HLL with other precision and Google signals. If the
difference is above ~2-3% for sessions, look at `docs/troubleshooting.md`.

## GA4 (ga4_reports)

| GA4 UI | table |
|---|---|
| Home cards | `rpt_ga4_overview_last_28_days` |
| Realtime | `rpt_ga4_realtime` (`include_intraday`) |
| Acquisition > User acquisition | `rpt_ga4_user_acquisition_daily` |
| Acquisition > Traffic acquisition | `rpt_ga4_traffic_acquisition_daily` |
| Engagement > Overview | `rpt_ga4_engagement_overview_daily` |
| Engagement > Events | `rpt_ga4_events_daily` |
| Engagement > Key events | `rpt_ga4_key_events_daily` |
| Engagement > Pages and screens | `rpt_ga4_pages_and_screens_daily` |
| Engagement > Landing page | `rpt_ga4_landing_pages_daily` |
| Monetization > Ecommerce purchases | `rpt_ga4_ecommerce_purchases_daily` |
| Monetization > Purchase journey / Checkout journey | `rpt_ga4_purchase_journey_daily`, `rpt_ga4_checkout_journey_daily` |
| Monetization > Promotions | `rpt_ga4_promotions_daily` |
| Monetization > In-app purchases / Publisher ads | `rpt_ga4_in_app_and_ads_daily` |
| Retention | `rpt_ga4_retention_overview` |
| User attributes > Demographic details | `rpt_ga4_demographics_daily` |
| Tech > Tech details | `rpt_ga4_tech_daily` |
| Explorations > Free form | `rpt_ga4_free_form_cube_daily` |
| Explorations > Funnel exploration | `fnl_<name>_daily` (open and closed, `cfg_funnels.js`) |
| Explorations > Path exploration | `rpt_ga4_path_exploration`, `prod_top_session_paths`, `prod_page_transitions` |
| Explorations > Segment overlap | `seg_segment_overlap` |
| Explorations > Cohort exploration | `coh_retention_weekly`, `coh_retention_monthly`, `coh_retention_matrix_wide` |
| Explorations > User lifetime | `rpt_ga4_user_lifetime` |
| Explorations > User explorer | `rpt_ga4_user_explorer` |
| Advertising > Model comparison | `attr_model_comparison` |
| Advertising > Conversion paths | `attr_top_conversion_paths` |
| Admin > DebugView (what is arriving) | `watch_event_registry`, `gov_event_dictionary` |

## Universal Analytics (ga4_reports_ua)

| UA report | table |
|---|---|
| Audience > Overview | `rpt_ua_audience_overview_daily` |
| Audience > Active Users | `rpt_ua_active_users_daily` |
| Audience > Lifetime Value | `rpt_ua_lifetime_value` |
| Audience > Geo > Location / Language | `rpt_ua_geo_daily` |
| Audience > Behavior > New vs Returning | `rpt_ua_new_vs_returning_daily` |
| Audience > Behavior > Frequency & Recency | `rpt_ua_frequency_recency` |
| Audience > Behavior > Engagement | `rpt_ua_engagement_buckets` |
| Audience > Technology > Browser & OS | `rpt_ua_browser_os_daily` |
| Audience > Technology > Network > Hostname | `rpt_ua_hostnames_daily` |
| Audience > Mobile > Devices | `rpt_ua_mobile_devices_daily` |
| Acquisition > All Traffic > Channels (original UA rules) | `rpt_ua_channels_daily` |
| Acquisition > All Traffic > Source/Medium | `rpt_ua_source_medium_daily` |
| Acquisition > All Traffic > Referrals | `rpt_ua_referrals_daily` |
| Acquisition > Campaigns | `rpt_ua_campaigns_daily` |
| Behavior > Behavior Flow | `rpt_ua_behavior_flow` |
| Behavior > Site Content > All Pages | `rpt_ua_all_pages_daily` |
| Behavior > Site Content > Content Drilldown | `rpt_ua_content_drilldown_daily` |
| Behavior > Site Content > Landing Pages | `rpt_ua_landing_pages_daily` |
| Behavior > Site Content > Exit Pages | `rpt_ua_exit_pages_daily` |
| Behavior > Site Content > Navigation Summary | `rpt_ua_navigation_summary` |
| Behavior > Site Search > Overview | `rpt_ua_site_search_overview_daily` (terms: `prod_site_search_terms`) |
| Behavior > Events (Category / Action / Label) | `rpt_ua_events_daily` |
| Conversions > Goals > Overview | `rpt_ua_goals_overview_daily` |
| Conversions > Goals > Reverse Goal Path | `rpt_ua_reverse_goal_path` |
| Conversions > Goals > Funnel Visualization | `fnl_<name>_daily` (closed counts) |
| Conversions > Ecommerce > Overview | `rpt_ua_ecommerce_overview_daily` |
| Conversions > Ecommerce > Product Performance | `rpt_ua_product_performance_daily` |
| Conversions > Ecommerce > Sales Performance | `rpt_ua_sales_performance` |
| Conversions > Ecommerce > Shopping / Checkout Behavior | `ecom_shopping_behavior_daily`, `ecom_checkout_behavior` |
| Conversions > Ecommerce > Product List Performance | `ecom_item_list_performance` |
| Conversions > Ecommerce > Marketing (coupons, affiliates) | `rpt_ua_coupons_and_affiliates` (internal promotion: `rpt_ga4_promotions_daily`) |
| Conversions > Ecommerce > Time to Purchase | `rpt_ua_time_to_purchase` |
| Conversions > Multi-Channel Funnels > Overview / Assisted | `rpt_ua_mcf_overview`, `attr_assisted_conversions` |
| Conversions > Multi-Channel Funnels > Top Conversion Paths | `attr_top_conversion_paths` |
| Conversions > Multi-Channel Funnels > Time Lag / Path Length | `attr_time_lag_and_path_length` |
| Conversions > Attribution > Model Comparison Tool | `attr_model_comparison` |
| Custom report "hour x weekday" | `rpt_ua_hour_of_day_daily` |
| (new) why the bounce rate dropped after the migration | `rpt_ua_bounce_rate_comparison` |

UA formulas kept on purpose: bounce = one page without interaction events, avg time on page =
time on page / (pageviews - exits), unique pageviews = sessions with the page, unique events =
sessions with the event.
