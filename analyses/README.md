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

## extras pack: more sectors and cross data (71 to 84)

New sectors, questions that cross GA4 with costs, calendar, catalog and identity, and the queries
over the extras models (`docs/extras.md`, rules in `includes/cfg_extras.js`). Every sector file
works on the core tables alone; set the event names in the `DECLARE`s at the top and run it as a script.

| file | when | who asks |
|---|---|---|
| `71_sector_banking_fintech.sql` | banks, fintechs, insurance, telecom: where the application dies, sessions to decide, the amount that scares, cost per APPROVED | product, media, risk |
| `72_sector_streaming_video.sql` | streaming, VOD, podcasts: drop off per title, binge hours, titles that sell the plan, fading viewers | content, CRM |
| `73_sector_news_paywall_newsletters.sql` | news, paywalls: the meter curve, paywall per section, what subscribers read, newsletter as a bridge | newsroom, revenue |
| `74_sector_travel_tickets_events.sql` | travel, tickets, events: booking window, demand not met, search lead time, sell out velocity | revenue management, media |
| `75_sector_education_courses.sql` | schools, courses: course -> lead -> enrollment, the season vs last year, content that helps, when to call | admissions, media |
| `76_sector_marketplace_sellers.sql` | marketplaces: seller scorecard, concentration (Herfindahl), buy box, sellers that bring new customers | marketplace ops, finance |
| `77_sector_classifieds_auto_real_estate.sql` | classifieds, cars, real estate: listings with no contact, demand x supply by price, serious buyers per channel, hot segments | sales, product |
| `78_sector_donations_nonprofits.sql` | NGOs, crowdfunding: one time vs recurring, the anchor of the suggested amounts, campaigns that bring donors back | fundraising |
| `79_browse_here_buy_there.sql` | any: research device x purchase device, weekend research weekday purchase, app x web value | media, board |
| `80_first_session_predicts_value.sql` | any: what in the first visit predicts the 90 day value (lift table and a points score) | CRM, media, data science |
| `81_journey_archetypes.sql` | any: the 15 journeys of the first 3 sessions, openers vs closers, what the buyers of the same journey did | marketing, attribution |
| `82_cross_data_new_marts_tour.sql` | one question per cross data mart: calendar x media, launches, wishlist, regional, events playbook, first category LTV, brand cannibalization, login value | everybody |
| `83_executive_one_pager.sql` | the board page: month to date vs last month and last year, and the 5 channels that moved the money split in traffic / conversion / ticket | board, CEO |
| `84_ga4_ui_extra_reports_cookbook.sql` | how to read the new GA4 replicas (monetization cards, all channels ROAS, acquisition cohort grid, leads, enhanced measurement, device models) | analysts |
