<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# data fixes

Everything the project corrects in the GA4 data, where it happens and the column that tells you
it happened. The rule is: fix it, flag it, never hide it.

| problem | where | fix | flag |
|---|---|---|---|
| exact duplicated rows in the export | `stg_ga4__events` | keep one row per event fingerprint | `duplicate_count` |
| GA4 rewrites old shards (late hits, reprocessing) | `stg_ga4__events` | reload from the oldest changed shard (`__TABLES__.last_modified_time`) | `ops_incremental_watermarks`, `dq_source_shards` |
| intraday + daily of the same day = double count | `stg_ga4__events` | intraday only for days without daily shard | `source_table_type` |
| PII in urls, titles, referrers (forms by GET, e-mail in UTM...) | `stg_ga4__events` | masked with `[email]`, `[cpf]`, `[redacted]`... | raw leaks listed in `priv_pii_findings` |
| user_id that is an e-mail / CPF | `stg_ga4__events` | replaced by its SHA256 | `user_id_was_hashed` |
| params with the wrong type (value as string, etc) | `ga4.js` param helpers | `paramAny` / numeric coalesce of every value field | `watch_param_registry.has_type_drift` |
| page_location with tracking params, trailing slash, case | `stg_ga4__events` | clean `page_path` (lower, no query, no slash) | original in `page_location` |
| payment gateway as referral (PagSeguro, Mercado Pago, PayPal...) | `int_ga4__session_traffic` | ignored, the previous source stays | `excluded_referral_source`, `excluded_referral_reason` |
| self referral (own hostname / subdomain as source) | `int_ga4__session_traffic` | ignored | same columns |
| gclid present but source says direct / (not set) | `int_ga4__session_traffic` | google / cpc (and the campaign from the Google Ads click report when enabled) | `traffic_fix_applied` |
| direct sessions losing the campaign | `int_ga4__session_traffic` | last non-direct carry over (`session_lookback_days`), GA4 style | `is_carried_over`, `carried_days_ago` |
| AI assistants (ChatGPT, Perplexity, Gemini...) mixed in Referral | `channels.js` | own group in the custom grouping | `session_custom_channel_group` |
| `session_engaged` missing (consent, MP, old tags) | `int_ga4__sessions_base` | GA4 public rule: 10s+, 2+ views or key event | `is_engaged` vs `is_engaged_ga4` |
| purchase sent twice (thank you page reload) | `int_ga4__transactions` | one row per transaction_id across the whole history | `fct_transactions` unique, assertion |
| test orders in production | `fct_transactions` | `is_test_transaction` out of revenue | `is_valid_for_revenue` |
| absurd order values (R$ 1.000.000 typo) | `fct_transactions` | robust z-score (MAD) + `max_realistic_order_value` | `is_revenue_outlier` |
| boleto / PIX that never get paid | `biz_corrected_revenue` | CRM status when enabled, else the expected paid rate by payment type (`cfg_project.expected_paid_rate`) | `unpaid_revenue`, `unpaid_estimate_method` |
| item revenue missing (only price x quantity) | `stg_ga4__event_items` | item_revenue = price * quantity when empty | `item_revenue_fixed` |
| refunds as separate events | `int_ga4__refunds` | joined to the order | `refunded_value`, `net_revenue` |
| bots and crawlers (datacenter cities, superhuman speed) | `int_ga4__session_bot_signals` | score 0-100 | `is_bot_suspect`, `bot_score` |
| debug / internal / non production hostnames | `stg_ga4__events` | flagged, dropped from sessions on | `is_debug`, `is_internal_traffic`, `is_non_production_host` |
| one device, many people (shared login) | `int_ga4__user_stitching` | the most recent user_id of the device wins, sharing flagged | `is_shared_device`, `user_ids_on_device` |
| anonymous sessions before the login | `int_ga4__user_stitching` | retroactive stitching: the whole device history gets the user_key | `is_identified` |
| user_id 'undefined' / 'null' / '0' (broken dataLayer) or a shared account on 50+ devices | `int_ga4__user_stitching` | ignored for stitching, otherwise thousands of devices become one "user" | `had_ignored_user_id`, `dq_identity_resolution` |
| two devices of the same person that never logged in (in-app browser -> Safari, checkout in another domain) | `int_ga4__identity_graph` | linked by the same order or the same ad click minutes apart, same OS | `identity_method` |
| bots that look human in one session (cron visits, teleporting between countries, credential stuffing) | `int_ga4__device_bot_signals` | device level score over the last 90 days, joined in `fct_sessions` | `device_bot_score`, `is_bot_device` |
| campaign urls that lose the attribution (missing `?`, `&amp;`, utm after `#`, typos in param names, auto tagging ids without utms...) | `int_ga4__session_tagging_checks` | not fixable after the fact: flagged, sized and explained | `url_issues`, `mkt_url_tagging_issues` |
| url with utms but GA4 did not process them (no `source` / `medium` event param, or (direct) / (not set)) | `int_ga4__session_tagging_checks` | flagged and sized per campaign | `is_attribution_lost`, `mkt_utm_attribution_loss_daily` |
| consent denied = less data | `biz_consent_adjusted_kpis` | scale by the cookieless pings share of the day | `consent_denied_share` |
| each row of a session has its own quality | `fct_sessions` | `data_quality_score` 0-100 + issues list | `is_trusted_session` |

When you need the number exactly as GA4 shows it, use the `rpt_ga4_*` tables (bots kept, GA4
rules) or the `ga4_native_*` columns. When you need the number that is closer to reality, use
the core and the marts.
