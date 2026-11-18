<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# analyses

Queries for the day to day. Dataform does not compile this folder, it is just SQL to copy,
paste in the BigQuery console and adapt. Replace `your-gcp-project` by your project (and the
`ga4_` prefix if you changed `schema_prefix`).

| file | when |
|---|---|
| `01_why_did_revenue_drop.sql` | somebody asks "why is revenue down?" |
| `02_channels_last_30_days.sql` | weekly marketing meeting |
| `03_landing_pages_to_fix.sql` | CRO backlog |
| `04_products_with_problems.sql` | merchandising / catalog meeting |
| `05_is_this_difference_real.sql` | before saying "it went up" (the stats UDFs) |
| `06_one_user_journey.sql` | support / product: what did this person do? |
| `07_who_to_call_today.sql` | CRM / sales: valuable customers at risk |
| `08_tracking_health_monday.sql` | analytics team, every monday |
| `09_month_pacing.sql` | "are we going to hit the target?" |
| `10_utm_mess.sql` | send to the agency |
| `11_media_quality.sql` | bots, broken urls and lost attribution per campaign |
| `12_what_really_works.sql` | every lift measured (holdouts, tests, interventions, promos) |
| `13_what_was_that_spike.sql` | "what happened yesterday at 21h?": bursts, blackouts and peak load |
| `14_merchandising_moves.sql` | weekly list of who decides the shelf: positions, gems, substitutes, reminders |
| `15_who_broke_the_habit.sql` | CRM: regular users late for their own rhythm, open missions with value |
| `16_is_the_number_real.sql` | before presenting a number: mix vs rate, shrunk rates, peeking, UI vs BigQuery |

## business questions and sectors (17 to 52)

The questions every business asks, the sector specific ones and the queries over the `frontier` and
`attribution_extended` models: see `README_business_questions.md`.

## insights: from the first week to the specialist (53 to 70)

Queries over the `insights` models (`docs/insights.md`) and the new functions of `ga4_udf`. The
level says who can run and explain them alone; every file is commented for the level below it.
Run after `dataform run --tags insights` (or the daily / weekly runs). 67 needs `enable_search_console`.

| file | when | level |
|---|---|---|
| `53_ga4_export_cookbook_junior.sql` | the first week: the raw export from zero (shards, params, sessions, purchases, consent, sources) and the same with the core tables | junior |
| `54_averages_lie_session_distributions.sql` | "engagement time went up": medians, percentiles and empty sessions before celebrating | junior |
| `55_what_was_the_visit_for.sql` | intent mix of the visits per channel, research sessions that buy later, post purchase service | mid |
| `56_user_flows_and_sankey.sql` | the Sankey of the site, the moves of the buyers, pages read by few that sell a lot | mid |
| `57_where_the_funnel_broke_this_week.sql` | monday CRO: the steps that changed for real, with the money, and the funnel of people per cohort | senior |
| `58_can_we_test_this.sql` | before an A/B test: MDE and days needed; after it: does the effect change by segment | mid |
| `59_kpi_regimes_and_forecast.sql` | when the level of each KPI changed, the weekday effect, and the forecast without BQML | specialist |
| `60_is_the_channel_really_better.sql` | bootstrap intervals per channel (and of your own metric), the dimensions that explain the purchase | specialist |
| `61_media_budget_moves.sql` | marginal ROAS, the better split of the same budget, ROAS of the people each campaign brought | senior |
| `62_campaign_naming_and_message_match.sql` | the naming convention audit (send to the agency) and the keywords landing on the wrong page | mid |
| `63_customer_health_and_second_purchase.sql` | the call list of valuable customers at risk, and what in the first order brings people back | mid |
| `64_assortment_strategy.sql` | ABC x XYZ, the departments the customers draw, misplaced products, how each launch spreads | senior |
| `65_did_it_really_work.sql` | feature impact after matching, the geo test with a synthetic control next to the DiD | specialist |
| `66_month_target_and_kpi_tree.sql` | the chance of hitting the target and the revenue tree WoW / YoY, by device | junior |
| `67_seo_after_ai_overviews.sql` | pages and queries that lost clicks with the same ranking, demand by search intent | senior |
| `68_export_limits_and_storage.sql` | the 1M events a day limit of the export, the events and params that eat the bytes | mid |
| `69_monday_insights_feed.sql` | the feed of the week in the order to read, one list per team, a text ready for Slack | junior |
| `70_analyst_training_exercises.sql` | 12 exercises with solutions, junior to specialist (windows, cohorts, funnels, z test, Wilson, PELT) | all |
