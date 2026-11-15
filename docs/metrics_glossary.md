<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# metrics glossary

One definition per metric, the same in every table. If a dashboard shows a different number with
the same name, the dashboard is wrong (or it is a `rpt_ua_*` table, those keep the UA formulas on
purpose, see the end).

## traffic and engagement

| metric | definition | where it is born |
|---|---|---|
| session | one `user_pseudo_id` + `ga_session_id` with at least one event | `int_ga4__sessions_base` |
| users | distinct `user_key` (stitched person: `uid:` when logged in at some point, else `dev:` device) | everywhere, `users_hll` for merging days |
| active users | users with an engaged session, a first visit or any engagement time (GA4 definition) | `metrics.activeUser` |
| new users | sessions with `ga_session_number = 1` or a `first_visit` / `first_open` | `fct_sessions.is_new_user` |
| engaged session | GA4 flag, or 10s+ of engagement, or 2+ views, or a key event (the public rule, applied when the flag is missing) | `fct_sessions.is_engaged` |
| engagement rate | engaged sessions / sessions | |
| bounce rate (GA4) | 1 - engagement rate | `is_bounce_ga4` |
| bounce rate (UA) | sessions with 1 view and no interaction event / sessions | `is_bounce_ua` |
| engagement time | sum of `engagement_time_msec` of the session (foreground time) | `engagement_time_sec` |
| views | page_view + screen_view | |

## conversion and money

| metric | definition |
|---|---|
| key events | events of `cfg_key_events.js`, counting method "once per event" or "once per session" as configured |
| conversion rate | sessions with purchase / sessions (session scope). User scope tables say so in the name |
| transactions / orders | distinct valid `transaction_id` (`is_valid_for_revenue`: not test, not outlier, not cancelled in the CRM) |
| **revenue (official)** | `SUM(revenue) WHERE is_valid_for_revenue` in `fct_transactions` |
| gross revenue all | every order, tests and outliers included (only for reconciliation) |
| net revenue | revenue - refunds |
| expected paid revenue | revenue - unpaid boleto / PIX estimate (`biz_corrected_revenue`) |
| AOV | revenue / orders |
| revenue per session / per user | revenue / sessions, revenue / users |
| items per order | items sold / orders |
| new customer revenue | revenue of orders with `order_number = 1` (stitched user) |
| ROAS | revenue / cost of the same platform and period, last non-direct click unless the table says another model (`attr_campaign_by_model` has one column per model) |
| CAC | cost / new customers of the period (`blended_cac` = all costs / all new customers) |
| LTV | realized: revenue of the user since the first visit (`rpt_ua_lifetime_value`, `coh_ltv_curves`); predicted: `ds_scores_ltv` (BQML) or `ds_btyd_customer_clv` (BTYD) |

## lifts and media quality

| metric | definition |
|---|---|
| lift (relative) | (treated - counterfactual) / counterfactual. Counterfactual = holdout group, control series or pre period trend, see `lift_registry.evidence_level` |
| incremental buyers / revenue | what exists only because of the program: (rate treated - rate holdout) x treated people |
| adjusted lift | Mantel-Haenszel risk ratio of a behaviour, stratified by device, new / returning, channel and landing page type. Association only |
| attribution loss share | tagged sessions that GA4 did not attribute (no `source` / `medium` event param, or (direct) / (not set)) / tagged sessions |
| media quality score | 100 - 45 x bot share - 25 x attribution loss - 15 x tagging issues - 15 x (1 - engagement rate of the humans) |
| dedup rate | 1 - people / devices (`dq_identity_resolution`) |

## quality

| metric | definition |
|---|---|
| data quality score | 0-100 per session, starts at 100 and loses points per issue (`fct_sessions.data_quality_issues`) |
| trusted session | score >= 70 and not a bot |
| data trust index | 0-100 per day from `dq_scorecard_daily`, weighted by how much each check matters |
| LGPD score | 0-100 from `priv_lgpd_scorecard` |

## UA formulas kept in rpt_ua_*

- unique pageviews = sessions that viewed the page
- avg time on page = time on page / (pageviews - exits)
- unique events = sessions with the event
- goal conversion rate = goal completions / sessions (can be above 100% in UA too)
- bounce = one page and no interaction event
