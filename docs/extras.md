<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# extras pack

More GA4 UI replicas, cross data marts and vertical marts (banking, streaming, news, travel).
Everything is new files: no existing model, config or doc was changed. Business rules of the pack
are in `includes/cfg_extras.js`; the vertical marts are OFF until you set `enabled: true` there.
Queries over all of it: `analyses/71` to `analyses/84`.

## GA4 UI replicas (`ga4_reports`)

| GA4 UI | table | notes |
|---|---|---|
| Acquisition > Traffic acquisition, session primary channel group | `rpt_ga4_custom_channel_acquisition_daily` | custom channel group next to the default one |
| Acquisition > Traffic acquisition, manual dimensions | `rpt_ga4_manual_campaigns_daily` | utm source / medium / campaign / id / term / content |
| Acquisition > Google Ads campaigns | `rpt_ga4_google_ads_campaigns_daily` | campaign, ad group, keyword |
| Acquisition > User acquisition cohort | `rpt_ga4_user_acquisition_cohort` | monthly cohorts per first channel, month 0..12 |
| Tech > Tech details, device brand / model | `rpt_ga4_device_models_daily` | |
| Free form with Hostname | `rpt_ga4_hostnames_daily` | session and landing hostname, non production flag |
| Retention, by session number | `rpt_ga4_new_established_daily` | 1st, 2nd, 3-5, 6-10, 11+ |
| Monetization > Overview | `rpt_ga4_monetization_overview_daily` | total revenue, purchasers (HLL), ARPU, ARPPU, valid revenue |
| Monetization > Ecommerce purchases by item category / brand / list | `rpt_ga4_item_categories_daily` | incremental |
| Explorations with Transaction ID | `rpt_ga4_transactions` | view with the GA4 names + the project flags |
| Business objectives > Generate leads | `rpt_ga4_lead_generation_daily` | lead acquisition + disqualification / conversion reasons |
| Engagement > Events, enhanced measurement params | `rpt_ga4_enhanced_measurement_daily` | scroll, outbound, downloads, video, forms, site search |
| Advertising > Performance > All channels | `rpt_ga4_advertising_all_channels_daily` | cost of every cost source mapped to the channel |
| Search Console > Queries | `rpt_ga4_search_console_queries_daily` | `enable_search_console` |
| Search Console > Google organic search traffic | `rpt_ga4_google_organic_search_traffic` | `enable_search_console` |

## cross data marts

| table | crosses | the question |
|---|---|---|
| `mkt_calendar_media_efficiency` | calendar x costs x GA4 | on which special days the media money works better or worse than a normal day |
| `mkt_brand_paid_organic_cannibalization` | GA4 x costs (x Search Console) | how much of the brand paid search is incremental |
| `ecom_launch_cannibalization` | catalog x orders | did the launch grow the category or steal from the siblings |
| `ecom_wishlist_to_purchase` | item events x orders x catalog | the wishlist as demand: conversion, substitutes, price drop alerts |
| `ecom_regional_bestsellers` | orders x geo | what each state buys more than Brazil (location quotient) |
| `ecom_first_category_ltv` | first order x later orders | which department makes the best customers |
| `biz_upcoming_events_playbook` | calendar (future) x last year's orders x channels x items | the planning sheet of the next special days |
| `biz_identified_vs_anonymous_value` | sessions x identity | the value of a login |

## vertical marts (off by default)

| table | sector | switch |
|---|---|---|
| `fnl_banking_application_daily` | banks, fintechs, insurance, telecom | `cfg_extras.banking.enabled` |
| `prod_streaming_titles` | streaming, VOD, podcasts, courses | `cfg_extras.streaming.enabled` |
| `prod_news_paywall_funnel` | news, magazines, paywalls | `cfg_extras.news_paywall.enabled` |
| `ecom_travel_search_demand` | travel, hotels, tickets | `cfg_extras.travel.enabled` |

## assertions

`definitions/90_assertions/assertions_extras.js` (tag `extras`): unique grain of the new tables, rates
between 0 and 1, and the launch split (incremental + cannibalized = launch revenue).

## running only the pack

```
dataform run --tags extras                     # assertions of the pack
dataform run --actions rpt_ga4_monetization_overview_daily ecom_wishlist_to_purchase ...
```

The new models also carry the usual area tags (`marketing`, `ecommerce`, `ga4_report`, `daily`), so the
daily run already builds them.
