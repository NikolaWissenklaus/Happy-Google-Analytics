<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# happy_google_analytics

Dataform project (core 3.0.71) on top of the GA4 BigQuery export. It goes from the raw events to
attribution, anomaly detection, data science, LGPD controls and activation, with the export
problems fixed on the way (and every fix flagged, so you always know what changed).

Brazilian by default (BRL, America/Sao_Paulo, UFs with IBGE population, brazilian holidays and
retail calendar, CPF / CNPJ alfanumérico / boleto / PIX), but everything is a var or a config.

## who uses what

| you are | start here |
|---|---|
| data engineer | `docs/architecture.md`, `docs/runbook.md`, `ga4_ops`, `ga4_data_quality` |
| data analyst | `docs/data_contracts.md`, `docs/metrics_glossary.md`, `ga4_core`, `analyses/` |
| analytics / CRO specialist | `ga4_reports`, `ga4_reports_ua`, `ga4_cro`, `ga4_funnels`, `ga4_attribution`, `ga4_watch` |
| marketing / media | `ga4_marketing` (+ `mkt_media_quality_scorecard`), `ga4_attribution`, `ga4_lifts`, `ga4_audiences`, `ga4_activation` |
| product | `ga4_product`, `ga4_funnels`, `ga4_cohorts` |
| business / directors | `biz_executive_weekly_summary`, `biz_daily_scorecard`, `biz_targets_pacing`, `biz_revenue_bridge`, `biz_opportunity_sizing` |
| DPO (encarregado) | `docs/lgpd.md`, `priv_lgpd_scorecard` |

## quick start

1. `workflow_settings.yaml`: `defaultProject`, `defaultLocation`, `ga4_project`, `ga4_dataset`, `site_hostnames`.
2. Business rules in `includes/cfg_*.js` (key events, funnels, audiences, channels, promotions, targets, tracking plan, privacy).
3. `cd tools && npm install && npm run check` (JS UDF tests + compile + every statement parsed with sqlglot, BigQuery dialect, with a lint for the errors a parser accepts and BigQuery does not).
4. Run the tag `bootstrap` once, then `daily` every day, `assertions` after it (`weekly` for BQML, `hourly` with intraday).

Details in `docs/configuration.md` and `docs/runbook.md`.

## layers (one dataset each, `<prefix>_<layer>`)

| folder | what |
|---|---|
| `00_sources` | declarations: GA4 export, intraday, user export, Google Ads, Meta Ads, Search Console, CRM, DSR table |
| `01_udfs` | 50 persistent functions for the pipeline and the analysts: params, urls, channel grouping, PII (CPF / CNPJ alfanumérico / Luhn), stats (normal CDF, Wilson, z-test, Bayes, Welch, chi-square, sequential test), BG/NBD, Gamma-Gamma, Markov, Shapley, CUSUM, PageRank, absorbing Markov values, brazilian calendar |
| `02_seeds` | reference tables from the configs (UF + IBGE 2022, pt stopwords, tracking plan, promotions, targets...) |
| `10_staging` | `stg_ga4__events` (dedup, PII masking, export fixes, auto backfill when Google rewrites shards, LGPD suppression), items, params, user properties + other sources |
| `20_intermediate` | sessions, traffic source (last non-direct carry over, gclid / payment gateway / self referral fixes), bot score per session AND per device (impossible travel, cron like visits, credential stuffing...), page views with time on page, identity graph (login + same order + same ad click) with retroactive stitching, campaign url checks, deduplicated transactions, key events, costs |
| `30_core` | `fct_sessions` (row level data quality score), transactions, items, key events, user daily + dims (users, items, pages, campaigns, calendar BR). Contract in `docs/data_contracts.md` |
| `40_marts` | marketing (25, with media quality: url tagging problems, attribution loss, campaign scorecard), attribution (13: 7 rule models + Markov + Shapley + MCF), lifts (5: activation holdouts, interventions, adjusted behaviour lift, registry), ecommerce (26), promotions (7), product (26), business (16), CRO (14, with A/B analyzer, sequential test and CUPED), SEO (5), funnels (generated), cohorts (6), segments (12), audiences (generated), CRM (4) |
| `50_reports` | 21 GA4 UI replicas and 32 Universal Analytics reports rebuilt on GA4 data (Behavior Flow, Navigation Summary, Reverse Goal Path, Content Drilldown, MCF, Time to Purchase...) |
| `60_data_science` | feature store without leakage, heuristic scores, BQML (propensity + gains, churn, LTV, k-means, ARIMA_PLUS with BR holidays, MMM-lite), BTYD fitted inside BigQuery, correlations, lagged correlations, Kaplan-Meier, geo DiD, search n-grams, shopping missions, order risk signals |
| `70_monitoring` | data quality (24 tables + Data Trust Index, identity resolution, bot traffic, tracking blackouts, UI vs BigQuery explainer), anomaly detection (8 methods + ensemble + root cause + alert feed), LGPD (19: consent, PII scanner on the raw export, DSR access / deletion with suppression list, retention, inventory, scorecard), GA4 change watch (11: export schema timeline, event / param / user property / item param registries, new values, channel drift, streams, changelog), governance (living event dictionary, tracking plan coverage and violations, custom definitions vs quota, url parameter inventory), ops (inventory, job costs, table usage, freshness) |
| `80_activation` | consent gate, Google Ads offline conversions (gclid / gbraid / wbraid), Meta CAPI payloads, GA4 Measurement Protocol write back, CRM traits and triggers (with history), audience exports, optional holdouts |
| `90_assertions` | 19 assertions: no placeholder / giant users, uniqueness, core x mart x report reconciliation, attribution credits, closed funnels, PII after staging, activation only with consent, DSR SLA, deleted people stay deleted |

Optional modules (`enable_*` vars) compile out completely when off. Both extremes are validated.

## the parts I am proud of

- **Auto backfill that follows Google.** Staging reads `__TABLES__` and reloads the shards GA4
  rewrote; every incremental writes a watermark and the downstream ones follow it. No "why does
  last week not match the UI anymore".
- **Fix, flag, never hide.** Payment gateway referrals, gclid without source, duplicated purchases,
  test orders, absurd values, unpaid boleto / PIX, missing engagement flag... all corrected and all
  with a column saying so (`docs/data_fixes.md`). Every session has a 0-100 quality score.
- **Anomalies with a reason.** 8 methods vote, holidays need more votes, and the alert arrives
  with the root cause ("71% of the drop is Safari").
- **Data driven attribution you can read.** Markov removal effect and exact Shapley values run in
  JS UDFs, side by side with 7 rule based models and the old UA MCF reports.
- **LGPD as code.** PII scanner on the raw export, consent monitoring per page and channel, DSR
  access reports, deletion across every user level table found in INFORMATION_SCHEMA with an
  audit log and a hashed suppression list (a full refresh never brings a deleted person back),
  retention purge with dry run, ROPA-lite inventory, activation gated by consent and audited.
- **GA4 change watch.** The schema of every export shard is kept, so "when did Google add this
  column?" and "when did the dev team kill this event?" have an answer with a date.
- **Who is who, and who is not a person.** Devices that never logged in are merged when they
  share an order or an ad click minutes apart (the Instagram browser -> Safari case), placeholder
  user_ids never stitch, and bots are judged by the whole behaviour of the device: impossible
  travel, visits every N minutes like a cron, many logins on one device.
- **Media quality.** Every way a campaign url loses the attribution (missing `?`, `&amp;`, utm after
  `#`, typos in the param names, msclkid without utms...), the sessions where GA4 never processed
  the utms, and a score per campaign with the money that went to bots.
- **Lifts that mean something.** Deterministic holdouts in the activation, interventions measured
  against a counterfactual, behaviour lift adjusted by Mantel-Haenszel, everything in one registry
  with the level of evidence.
- **UA is back.** Behavior Flow, Navigation Summary, Reverse Goal Path, Time to Purchase, Lifetime
  Value, the original UA channel rules, and a table that explains why the bounce rate "dropped"
  after the migration.

## labs: what the export can do and no GA4 report ever will

28 models and 3 functions with the tag `labs` (`dataform run --tags labs`), each one in the dataset of
its area. Knobs in `includes/cfg_labs.js`, the idea and the math of each one in `docs/labs.md`.

- **The site as a graph.** PageRank of the pages with the real navigation (`prod_internal_pagerank`)
  and the purchase probability of every step of the journey with an absorbing Markov chain
  (`prod_journey_state_values`): "cart -> home throws away N points of purchase probability".
- **Time, minute by minute.** Bursts of visits with the probable cause, from the e-mail blast to the
  TV spot nobody tagged (`mkt_traffic_bursts`), silent minutes that mean the site or the tag was down
  (`dq_tracking_blackouts`) and the peak of simultaneous users for the infra team
  (`prod_traffic_load_profile`).
- **People, not cookies or sessions.** How many "users" are the same person with a new cookie, per
  browser (`mkt_cookie_churn_inflation`), sessions cut in two by the 30 minute timeout
  (`prod_session_timeout_splits`), the shopping mission as the real unit of a purchase decision
  (`ds_shopping_missions`), the habit of each user and who just broke it (`seg_visit_rhythm`), and the
  size of the audience that never showed up, estimated like biologists count fish
  (`biz_market_size_capture_recapture`).
- **The shelf.** Prices ending in ,90 against round ones (`ecom_price_ending_psychology`), list
  positions without the position bias (`ecom_list_position_bias`), who steals the sale from whom
  (`ecom_item_switching`), the freight shock by state (`ecom_freight_shock`), the repurchase clock of
  each product (`ecom_replenishment_cycles`) and demand rising before the revenue
  (`ecom_item_momentum`).
- **Numbers you can trust.** Mix vs rate with a Simpson paradox alarm (`biz_simpson_paradox_watch`),
  rates shrunk by empirical Bayes so 2 sales in 9 sessions stop winning rankings
  (`cro_empirical_bayes_rates`), an A/B test you are allowed to peek at (`cro_ab_test_sequential`),
  CUPED to finish tests sooner (`cro_ab_test_cuped`) and the answer to "why does BigQuery not match
  the GA4 screen" (`dq_ui_vs_bigquery_explainer`).
- **And after.** What the customer does after the thank you page (`prod_post_purchase_behavior`), the
  synonyms the customers write in the search box (`prod_search_reformulations`), where each channel
  sends people next (`mkt_channel_return_matrix`), the tax of the in-app browsers
  (`mkt_in_app_browser_gap`), orders that deserve a second look (`ds_order_risk_signals`) and every
  parameter living in your urls (`gov_url_parameter_inventory`).

## docs

`docs/architecture.md` · `docs/configuration.md` · `docs/runbook.md` · `docs/data_contracts.md` ·
`docs/metrics_glossary.md` · `docs/data_fixes.md` · `docs/attribution.md` ·
`docs/anomaly_detection.md` · `docs/data_science.md` · `docs/lgpd.md` · `docs/activation.md` ·
`docs/report_mapping.md` · `docs/identity_and_bots.md` · `docs/media_quality.md` · `docs/lifts.md` · `docs/labs.md` · `docs/troubleshooting.md` · `docs/catalog.md` (generated: every
action with its description) · `analyses/` (queries for the day to day) · `CONTRIBUTING.md`

## status (honest)

- 498 actions: 414 tables / views / incrementals, 65 operations (50 UDFs, 6 BQML models, LGPD and
  bootstrap ops), 19 assertions. Compiles with every module off and every module on, 0 syntax
  problems in the 795 statements (sqlglot + lint), JS UDF tests green (`npm run test:udfs` and
  `node tests/test_labs_udfs.js`).
- **It was never run against a real BigQuery.** The validator checks syntax, not your schema: the
  first run will probably find a column name that your export does not have (see
  `docs/troubleshooting.md`), a permission missing for INFORMATION_SCHEMA / JOBS, or a mart that
  needs a smaller `mart_window_days`. Run it first in a dev project, with `start_date` close to today.
- The LGPD deletion and retention operations are OFF by default and must stay off until the DPO
  validates the preview tables. Nothing in this project sends data outside BigQuery: the
  activation tables are payloads, the sending is your job (`docs/activation.md`).
- Not legal advice. The LGPD layer helps to comply, it does not make anyone compliant by itself.

## every file and folder

```
happy_google_analytics/
├── workflow_settings.yaml   project, datasets and every var
├── includes/                JavaScript shared by the models: cfg_*.js = business rules, the rest = SQL builders
├── definitions/             everything Dataform compiles
│   ├── 00_sources/          declarations of the source tables
│   ├── 01_udfs/             persistent functions (calendar_geo, ga4_params, models, privacy, stats, traffic, urls_text)
│   ├── 02_seeds/            reference tables generated from the configs
│   ├── 10_staging/          one model per source table (ga4, google_ads, meta_ads, search_console, crm, costs)
│   ├── 20_intermediate/     sessions, traffic, bots, pages, identity, transactions, key events, costs
│   ├── 30_core/             facts and dimensions: the contract
│   ├── 40_marts/            attribution, audiences, business, cohorts, crm, cro, ecommerce, funnels, lifts,
│   │                        marketing, product, promotions, segments, seo
│   ├── 50_reports/          GA4 interface and Universal Analytics replicas
│   ├── 60_data_science/     features, BQML, BTYD, MMM, statistics, missions, risk
│   ├── 70_monitoring/       data quality, anomalies, GA4 change watch, governance, pipeline ops, LGPD
│   ├── 80_activation/       payloads for ads platforms and CRM
│   └── 90_assertions/       checks that fail the run
├── analyses/                ready queries (not compiled)
├── docs/                    documentation
└── tools/                   validator, tests, catalog generator, alert sender
```

One line per file below. For the models it is the first sentence of the description that goes to
BigQuery (the full one, with columns, tags and dependencies, is in `docs/catalog.md`). The kind is in
italics when it is not a plain table. Files ending in `.js` inside `definitions/` generate several
tables each.

### root

Project settings and the entry documents.

| file | what it does |
|---|---|
| `.gitignore` | Keeps credentials, node_modules, compiled output, python caches and any csv with real user data out of git |
| `CONTRIBUTING.md` | Rules to add a model (layer, naming, config block, incremental pattern, personal data), SQL style and what to run before a PR |
| `LICENSE` | MIT license |
| `README.md` | This file |
| `workflow_settings.yaml` | Dataform settings: core version, project, location, default datasets and every var of the project (GA4 export, processing window, attribution, optional modules, LGPD switches) |

### `includes/`

JavaScript available to every model. `cfg_*.js` are the business rules (the files you edit), the others are SQL builders.

| file | what it does |
|---|---|
| `cfg_anomaly.js` | Config: anomaly detection (history, thresholds of each method, votes needed, metrics watched) |
| `cfg_audiences.js` | Config: the audiences (SQL condition, consent, destinations, holdout) |
| `cfg_channels.js` | Config: source lists of the channel grouping (search, social, shopping, video, AI assistants, brazilian sites) |
| `cfg_costs.js` | Config: manual costs without a connector (influencers, fees, offline media) |
| `cfg_ds.js` | Config: data science (feature columns, BQML options, BTYD, forecasting, MMM) |
| `cfg_experiments.js` | Config: A/B tests (exposure event, experiments) and geo experiments by state |
| `cfg_funnels.js` | Config: the funnels (steps, scope, window) that funnels.js turns into tables |
| `cfg_identity.js` | Config: identity resolution (login stitching, graph links by order and click id, placeholder user_ids) |
| `cfg_key_events.js` | Config: key events (event, condition, counting method, value) |
| `cfg_labs.js` | Config: knobs of the labs models (missions, rhythm, bursts, blackouts, PageRank, post purchase patterns, order risk weights...) |
| `cfg_lifts.js` | Config: holdouts, dated interventions and behaviours for the lift measurement |
| `cfg_privacy.js` | Config: LGPD (sensitive url keys, user_id rules, consent params, DSR list and SLA, dataset classification) |
| `cfg_project.js` | Config: business rules of the property (brand terms, test orders, deferred payments, bot thresholds, page types, features, web vitals, BigQuery prices) |
| `cfg_promotions.js` | Config: promotion calendar and baseline for promo_calendar_lift |
| `cfg_targets.js` | Config: monthly targets of revenue, transactions, sessions and new customers |
| `cfg_tracking_plan.js` | Config: the tracking plan as code (events, params, types, required) |
| `channels.js` | SQL builders of the GA4 default channel group and of the custom grouping, shared by the pipeline and the UDFs |
| `constants.js` | Parses every var of workflow_settings.yaml once (types, optional modules, dataset names) and exposes the table name helpers |
| `content.js` | Page type classification and 404 detection, generated from cfg_project.js |
| `docs.js` | Column descriptions reused by many tables (docs.pick) |
| `ga4.js` | GA4 export SQL builders: param extraction, url parsing, cleaning, session key, event id, consent, masking |
| `helpers.js` | Generic SQL builders: literals, dates, the incremental pre / post operations with auto backfill, filters, Wilson interval, holdout, seeds |
| `lifts.js` | Holdout rules shared by the activation tables and by the lift measurement |
| `metrics.js` | Standard metric blocks over fct_sessions (GA4 and UA flavours) so every mart means the same thing |
| `privacy.js` | SQL builders for PII masking and detection, suppression filter, DSR deletion and retention purge |
| `reports.js` | Builder of the 'dimension x standard metrics' daily reports used by the GA4 and UA replicas |
| `seeds_br.js` | Brazilian reference data: states with IBGE 2022 population, macro regions, capitals, pt stopwords |
| `tagging.js` | Structural checks of campaign urls (missing ?, &amp;, utm after #, typos in param names, click ids without utms) |

### `definitions/00_sources/`

Declarations of the source tables. Nothing is created here.

| file | what it does |
|---|---|
| `ga4_export.js` | Declares the GA4 export: events_*, events_intraday_* and the user export tables (pseudonymous_users_*, users_*) (4 actions) |
| `google_ads.js` | Declares the Google Ads Data Transfer tables (campaigns, campaign stats, click stats with gclid). Optional module (3 actions) |
| `other_sources.js` | Declares the optional sources: Meta Ads insights, Search Console bulk export, CRM orders / customers and the DSR table (5 actions) |

### `definitions/01_udfs/calendar_geo/`

Persistent functions: brazilian calendar and geography.

| file | what it does |
|---|---|
| `br_holiday_name.sqlx` | Brazilian national holiday (feriado nacional) or national 'ponto facultativo' name of a date, NULL otherwise |
| `br_uf_from_region.sqlx` | Brazilian UF (SP, RJ, MG...) from GA4 country + region ('State of Sao Paulo', 'São Paulo', 'Federal District'...) |
| `easter_date.sqlx` | Easter sunday of a year (anonymous gregorian algorithm / Meeus-Jones-Butcher). Carnaval, Sexta-feira Santa and Corpus Christi come from it |
| `format_duration.sqlx` | Seconds to 'HH:MM:SS', like the old UA 'Avg. Session Duration' (00:02:37) |
| `iso_year_week.sqlx` | ISO year-week label: 2026-01-01 -> '2026-W01', 2027-01-01 -> '2026-W53' |

### `definitions/01_udfs/ga4_params/`

Persistent functions: reading event params, item params and user properties.

| file | what it does |
|---|---|
| `get_item_param.sqlx` | Item custom param (items.item_params) as STRING. ex: discount, size, color |
| `get_param_any.sqlx` | Any GA4 param value converted to STRING. Good for exploring params you dont know the type |
| `get_param_int.sqlx` | INT64 value of a GA4 param, also converting strings/doubles (ga_session_id, engagement_time_msec...) |
| `get_param_num.sqlx` | FLOAT64 value of a GA4 param no matter how it was sent (value, price, shipping...) |
| `get_param_str.sqlx` | String value of a GA4 param. Works with event_params, user_properties and items.item_params |
| `get_user_prop.sqlx` | User property value as STRING (user_properties array) |
| `has_param.sqlx` | TRUE when the param key exists in the array (even with NULL value) |

### `definitions/01_udfs/models/`

Persistent functions: models that run inside BigQuery (JS).

| file | what it does |
|---|---|
| `absorbing_markov_values.sqlx` | Absorbing Markov chain: for each state, the probability of ending in the success state (ex: purchase) instead of the failure state (ex: exit), and the expected number of steps until one of the two |
| `bg_nbd_predict.sqlx` | BG/NBD per customer: probability of being alive and expected purchases in the next N time units (horizon) |
| `cusum.sqlx` | Two sided tabular CUSUM over a standardized series (z scores, in date order). Resets after each alarm |
| `fit_bg_nbd.sqlx` | Fits a BG/NBD model (Fader, Hardie & Lee 2005) by maximum likelihood, Nelder-Mead in log space |
| `fit_gamma_gamma.sqlx` | Fits the Gamma-Gamma spend model (Fader & Hardie 2013) for the monetary part of the CLV. Only repeat customers (x > 0) |
| `gamma_gamma_expected_value.sqlx` | Expected average order value of a customer given x repeat purchases with mean m (Gamma-Gamma). x = 0 gives the population mean |
| `markov_removal_effects.sqlx` | Data driven attribution with a first order Markov chain: removal effect of each channel and its share of the conversions |
| `pagerank.sqlx` | Weighted PageRank of a graph given as an array of edges (src, dst, weight). Runs inside BigQuery, no export to Python |
| `shapley_values.sqlx` | Shapley value attribution (cooperative game theory) over the channel sets of the converting paths |

### `definitions/01_udfs/privacy/`

Persistent functions: PII detection, validation and hashing.

| file | what it does |
|---|---|
| `detect_pii.sqlx` | Returns the kinds of PII found in a text: email, cpf, cnpj, phone_br, cep, credit_card, sensitive_url_key |
| `hash_email.sqlx` | SHA256 hex of a normalized email (lower, trim). remove_gmail_dots = TRUE follows the Google Ads rule for gmail.com |
| `hash_phone_br.sqlx` | SHA256 hex of a BR phone in E.164. Google wants it with '+' (with_plus = TRUE), Meta wants only digits |
| `is_valid_cnpj.sqlx` | Validates a CNPJ, including the new alphanumeric CNPJ (Receita Federal, from jul/2026) |
| `is_valid_cpf.sqlx` | Validates a CPF with the check digits (formatted or not). Used to cut false positives in the PII scanner |
| `luhn_check.sqlx` | Luhn check for credit card like numbers (13 to 19 digits). A card number in GA4 is a PCI incident, not only LGPD |
| `normalize_phone_br.sqlx` | Brazilian phone to E.164: '(11) 98765-4321' -> '+5511987654321'. NULL when it does not look like a BR phone |

### `definitions/01_udfs/stats/`

Persistent functions: statistics.

| file | what it does |
|---|---|
| `benford_expected.sqlx` | Benford law expected share of a first digit (1-9): LOG10(1 + 1/d). 1 should start ~30.1% of natural values |
| `chi_square_pvalue.sqlx` | Upper tail p value of a chi-square statistic. Exact for df = 1, Wilson-Hilferty approximation for df > 1 |
| `msprt_p_value.sqlx` | Mixture sequential probability ratio test for the difference of two conversion rates |
| `normal_cdf.sqlx` | Standard normal CDF (Abramowitz & Stegun 7.1.26, error < 1.5e-7). BigQuery has no NORM.DIST, so here it is |
| `prob_b_beats_a.sqlx` | Bayesian A/B: P(rate_B > rate_A) with Beta posteriors. Exact sum (Evan Miller) up to 100k conversions, normal approx above |
| `welch_t_test.sqlx` | Welch t test for two means (ex: revenue per user in an A/B test). p value with normal approx, ok for n > 30 |
| `wilson_interval.sqlx` | Wilson score interval for a rate (successes / trials). Use .low to rank pages/products without the small sample noise |
| `z_test_proportions.sqlx` | Two proportions z test (pooled). Returns rates, absolute diff, relative uplift, z and two sided p value |

### `definitions/01_udfs/traffic/`

Persistent functions: sources and channel grouping.

| file | what it does |
|---|---|
| `custom_channel_group.sqlx` | Custom channel group: GA4 default + AI Assistants, WhatsApp, Marketplaces, Cashback & Coupons, Influencers, Brand x Non-brand |
| `default_channel_group.sqlx` | GA4 default channel group from source / medium / campaign. Same rules (and order) GA4 uses |
| `is_ai_assistant.sqlx` | TRUE when the source is an AI assistant (chatgpt, perplexity, gemini, copilot, claude, deepseek...) |
| `is_payment_gateway.sqlx` | TRUE for payment gateways / 3DS / bank pages that steal the attribution (pagseguro, mercadopago, paypal...) |
| `normalize_source.sqlx` | Canonical source name: l.facebook.com / m.facebook.com / fb -> facebook, google.com.br -> google... (cfg_channels.js) |

### `definitions/01_udfs/urls_text/`

Persistent functions: urls and text.

| file | what it does |
|---|---|
| `clean_page_path.sqlx` | Normalized page path: lower case, no query string/fragment, no trailing slash, '/' for home |
| `mask_pii.sqlx` | Redacts sensitive query string values and emails / CPF / CNPJ / phones in a text |
| `normalize_text.sqlx` | Lower case, no accents, only letters/numbers and single spaces. Good for search terms and names |
| `path_level.sqlx` | UA style 'page path level N': path_level('/blog/2024/post-x', 1) = '/blog/', level 3 = '/post-x' |
| `remove_accents.sqlx` | Removes accents/diacritics: 'São Paulo, ação, pão' -> 'Sao Paulo, acao, pao' |
| `slugify.sqlx` | 'Black Friday 2026 - Calçados' -> 'black-friday-2026-calcados'. Handy for campaign names |
| `url_decode.sqlx` | decodeURIComponent with '+' as space. Returns the input when the string is not valid encoding |
| `url_param.sqlx` | Value of a query string param in a url (case insensitive key). ex: url_param(page_location, 'utm_source') |
| `url_path.sqlx` | Path of a url, as it is (keeps case and trailing slash). See clean_page_path for the normalized one |

### `definitions/02_seeds/`

Reference tables generated from the configs.

| file | what it does |
|---|---|
| `seeds.js` | Builds the reference tables from includes/cfg_*.js and seeds_br.js (states with IBGE population, stopwords, key events, tracking plan, promotions, targets, A/B tests, interventions, costs...) (15 actions) |

### `definitions/10_staging/costs/`

Staging of the manual costs.

| file | what it does |
|---|---|
| `stg_costs__manual_daily.sqlx` | Manual monthly costs (cfg_costs.js) spread evenly over the days of the month |

### `definitions/10_staging/crm/`

Staging of the backend / CRM (optional, `enable_crm`).

| file | what it does |
|---|---|
| `stg_crm__customers.sqlx` | Backend customers. Email and phone are only kept HASHED (Google and Meta formats), the clear text stays in the CRM. LGPD by design |
| `stg_crm__orders.sqlx` | Backend / ERP orders normalized. This is the source of truth for revenue: paid status, boleto/pix pending, cancellations and refunds |

### `definitions/10_staging/ga4/`

Staging of the GA4 export. The only place that reads the raw export.

| file | what it does |
|---|---|
| `stg_ga4__event_items.sqlx` | One row per item per ecommerce event (view_item_list, select_item, view_item, add_to_cart, purchase, refund, promotions...) *(incremental)* |
| `stg_ga4__event_params.sqlx` | Long format of every event param (one row per event x param). Base for the tracking plan checks, param registry, cardinality and type drift monitoring *(incremental)* |
| `stg_ga4__events.sqlx` | GA4 events, one row per event. Deduplicated, typed, most used params flattened, PII masked and the known export problems fixed *(incremental)* |
| `stg_ga4__user_export.sqlx` | GA4 user data export (pseudonymous_users_*), latest state per device: GA4 audiences, GA4 own predictions (purchase/churn probability) and lifetime numbers |
| `stg_ga4__user_properties.sqlx` | User properties, one row per day x user_pseudo_id x property with the last value of the day *(incremental)* |

### `definitions/10_staging/google_ads/`

Staging of Google Ads (optional, `enable_google_ads`).

| file | what it does |
|---|---|
| `stg_google_ads__campaign_daily.sqlx` | Google Ads cost / clicks / impressions per day and campaign, with the latest campaign name and type (Data Transfer Service) |
| `stg_google_ads__clicks.sqlx` | One row per Google Ads click (gclid) with campaign, ad group and keyword. Used to rescue the campaign of GA4 sessions with gclid and '(not set)' campaign |

### `definitions/10_staging/meta_ads/`

Staging of Meta Ads (optional, `enable_meta_ads`).

| file | what it does |
|---|---|
| `stg_meta_ads__insights.sqlx` | Meta Ads (Facebook / Instagram) daily insights at ad level, normalized. Expects the usual columns of Fivetran / Airbyte / Supermetrics exports |

### `definitions/10_staging/search_console/`

Staging of Search Console (optional, `enable_search_console`).

| file | what it does |
|---|---|
| `stg_gsc__site_impressions.sqlx` | Search Console bulk export at property level (queries), used for brand x non-brand organic demand |
| `stg_gsc__url_impressions.sqlx` | Search Console bulk export at url level, with the url normalized to the same page_path used in GA4 (so they can be joined) |

### `definitions/20_intermediate/conversions/`

Key events.

| file | what it does |
|---|---|
| `int_ga4__key_events.sqlx` | Key events (conversions) from cfg_key_events.js, one row per occurrence, with value and GA4 counting method applied (is_counted) *(incremental)* |

### `definitions/20_intermediate/costs/`

Costs of every platform in one shape.

| file | what it does |
|---|---|
| `int_costs__unified_daily.sqlx` | All marketing costs in one shape (date x platform x campaign): Google Ads, Meta Ads and manual costs |

### `definitions/20_intermediate/ecommerce/`

Transactions, refunds and the price history.

| file | what it does |
|---|---|
| `int_ga4__item_prices_daily.sqlx` | Price of each item per day, as seen by the users (median of the price in view_item / list / cart / purchase) *(incremental)* |
| `int_ga4__refunds.sqlx` | GA4 refund events (full and partial). Joined with the transactions in fct_transactions to get net revenue *(incremental)* |
| `int_ga4__transactions.sqlx` | One row per transaction, deduplicated across ALL history (the thank you page reloaded tomorrow does not count twice) *(incremental)* |

### `definitions/20_intermediate/pages/`

Page views with navigation context.

| file | what it does |
|---|---|
| `int_ga4__page_views.sqlx` | One row per page_view / screen_view with the position in the session, previous and next page, UA style time on page and the GA4 engagement time spent on that page (events are attached to the page... *(incremental)* |

### `definitions/20_intermediate/sessions/`

Sessions, traffic source, bot signals, tagging checks.

| file | what it does |
|---|---|
| `int_ga4__device_bot_signals.sqlx` | Bot score per DEVICE (user_pseudo_id) from its whole behaviour in the last days, not one session alone: impossible travel (another country minutes after the previous session), country hopping... |
| `int_ga4__session_bot_signals.sqlx` | Bot / spam score per session (0-100) from simple signals: datacenter city, robotic speed, ghost hostnames, empty sessions, devices with dozens of sessions a day, and the 'one and done' new device... *(incremental)* |
| `int_ga4__session_ecommerce_flags.sqlx` | Ecommerce behaviour per session: first time of each step (view_item ... purchase), counts and values *(incremental)* |
| `int_ga4__session_sources_raw.sqlx` | Source of each session ONLY looking at the session itself (no carry over yet) *(incremental)* |
| `int_ga4__session_tagging_checks.sqlx` | Campaign tagging checks per session: the utms the urls had, structural problems of the urls (includes/tagging.js), internal utms, utms that arrived only after the first page, and the attribution... *(incremental)* |
| `int_ga4__session_traffic.sqlx` | Final session traffic source, GA4 style: last non-direct click with carry over from previous sessions of the device (session_lookback_days), plus default and custom channel groups *(incremental)* |
| `int_ga4__sessions_base.sqlx` | One row per session (session_key) with counts, engagement, landing/exit page, device, geo and consent *(incremental)* |

### `definitions/20_intermediate/users/`

Identity graph and stitching.

| file | what it does |
|---|---|
| `int_ga4__identity_graph.sqlx` | Identity graph: devices linked by things only one person has (login, the same order, the same ad click minutes apart on the same OS), grouped in clusters by label propagation. int_ga4__user_stitching... |
| `int_ga4__user_id_pairs_daily.sqlx` | Device (user_pseudo_id) x user_id pairs seen per day. Small table that feeds the identity stitching without scanning all events every day *(incremental)* |
| `int_ga4__user_properties_latest.sqlx` | Latest value of each user property per device, plus when it was seen for the first and the last time |
| `int_ga4__user_stitching.sqlx` | Identity resolution: every device (user_pseudo_id) gets a user_key |

### `definitions/30_core/dimensions/`

Dimensions of the contract.

| file | what it does |
|---|---|
| `dim_calendar.sqlx` | Calendar with brazilian national holidays (Easter based ones calculated), retail dates (Black Friday, Dia das Maes, Dia dos Pais, Natal...), business days, '5o dia util' and the right dates to... |
| `dim_campaigns.sqlx` | Every campaign seen in GA4 (session campaign) with source/medium, channel, ad platform, brand flag, ids and lifetime performance |
| `dim_items.sqlx` | Product catalog as GA4 sees it: latest name / brand / categories, current price, first and last time seen, lifetime funnel numbers |
| `dim_pages.sqlx` | One row per page path: latest title, page type, content group, UA style path levels, 404 flag, first/last seen and lifetime views |
| `dim_traffic_sources.sqlx` | Every source / medium ever seen (after the fixes) with both channel groups, source category, first/last seen and lifetime numbers |
| `dim_user_identity.sqlx` | Device -> user_key map (login + identity graph). Join any table that has user_pseudo_id with this one to get the stitched user. identity_method tells how the device was linked *(view)* |
| `dim_users.sqlx` | One row per stitched user (user_key): acquisition (GA4 first user + our first session), lifetime engagement, purchases, LTV, recency, consent and latest user properties |

### `definitions/30_core/facts/`

Facts of the contract.

| file | what it does |
|---|---|
| `fct_ad_costs_daily.sqlx` | Marketing costs per day / platform / campaign (Google Ads, Meta Ads, manual), same shape for every source *(view)* |
| `fct_events.sqlx` | Every event (cleaned, from staging) + the session traffic + user_key. The 'I want everything' table for ad hoc analysis *(view)* |
| `fct_item_interactions.sqlx` | Every item level ecommerce event (impressions, clicks, views, carts, checkout, purchase, refund, promotions) with session context *(view)* |
| `fct_key_events.sqlx` | Key events (conversions) with the session context: channel, source/medium/campaign, landing page, device, user_key |
| `fct_page_views.sqlx` | Page views with session context (channel, device, landing page, new/returning, user_key) and the page type *(view)* |
| `fct_sessions.sqlx` | THE session table |
| `fct_transaction_items.sqlx` | One row per item sold (deduplicated transactions only), with the transaction context |
| `fct_transactions.sqlx` | One row per transaction with session context (channel, device, landing), refunds, net revenue, order sequence of the customer, robust outlier detection and (with the CRM module) the real payment... |
| `fct_user_daily.sqlx` | One row per user (user_key) per active day. Base of DAU/WAU/MAU, stickiness, retention, cohorts, lifecycle and the power user curve |

### `definitions/40_marts/attribution/`

Attribution: rule based models, Markov, Shapley, MCF.

| file | what it does |
|---|---|
| `attr_assisted_conversions.sqlx` | UA MCF 'Assisted Conversions' back from the dead: per channel and month, last click conversions, assisted conversions (channel in the path but not the last touch), first click and the assisted / last... |
| `attr_campaign_by_model.sqlx` | Same as attr_channel_by_model but at source / medium / campaign level, wide (one column per model) |
| `attr_channel_by_model.sqlx` | Conversions and value credited to each channel by each rule based model, by month and key event |
| `attr_channel_roles.sqlx` | What each channel does in the journey (last 90 days, multi touch paths only): introducer (first), assistant (middle) or closer (last), plus the first x last channel matrix in the same table (role =... |
| `attr_conversion_paths.sqlx` | One row per conversion (counted key event) with the ordered path of touches of the user inside the lookback window (conversion_lookback_days) |
| `attr_credits_rule_based.sqlx` | Credit of each touch of each conversion for 7 rule based models: first click, last click, last non-direct click (GA4 cross-channel last click), linear, time decay, position based (40/20/40) and... |
| `attr_data_driven_summary.sqlx` | One line per channel with the 3 opinions that matter (last 90 days, primary key event): last non-direct click (what GA4 reports by default), linear (the democratic one) and the data driven ones... |
| `attr_markov_removal_effects.sqlx` | Data driven attribution with Markov chains (removal effect), last 90 days, for the primary key event |
| `attr_model_comparison.sqlx` | The GA4 'Model comparison' (and the old UA Model Comparison Tool) for the last 90 days: conversions of each channel in every model, plus data driven (Markov and Shapley), and the % difference vs last... |
| `attr_shapley_values.sqlx` | Data driven attribution with exact Shapley values (cooperative game theory, the idea behind the first Google DDA) over the channel sets of the converting paths, last 90 days, for every key event |
| `attr_time_lag_and_path_length.sqlx` | UA MCF 'Time Lag' and 'Path Length' reports in one table (metric = time_lag / path_length), last 90 days |
| `attr_top_conversion_paths.sqlx` | GA4 'Conversion paths' / UA MCF 'Top Conversion Paths': most common channel paths to each key event (last 90 days), with conversions, value, average path length and days to convert |
| `attr_touchpoints.sqlx` | Every marketing touch (session) of every user in the attribution window, with the session OWN source (no carry over, otherwise the previous touch would count twice) |

### `definitions/40_marts/audiences/`

User features and the generated audiences.

| file | what it does |
|---|---|
| `aud_user_features.sqlx` | Feature table behind every audience of cfg_audiences.js (one row per user): open cart / checkout, recent views, purchases, RFM, value tier, propensity and churn scores (BQML when enabled, heuristic... |
| `audiences.js` | Generates one table per audience of cfg_audiences.js plus today's memberships, the daily membership history and the audience summary (19 actions) |

### `definitions/40_marts/business/`

Scorecards and analyses for directors.

| file | what it does |
|---|---|
| `biz_calendar_effects.sqlx` | Calendar effects for planning (last 365 days): revenue index by weekday, by day of month (salary days!), by holiday and by retail event vs a normal day of the same weekday |
| `biz_consent_adjusted_kpis.sqlx` | What the cookie banner hides: daily sessions and revenue we see with consent vs the cookieless pings (consent mode advanced) that arrive without user / session |
| `biz_corrected_revenue.sqlx` | From 'GA4 says' to 'the bank says', per day: raw purchase revenue of the export, minus duplicated purchases, internal/debug traffic, test orders, outliers, cancelled or never paid orders... |
| `biz_customer_concentration.sqlx` | How concentrated is the revenue of the last 365 days: share of the top 1% / 5% / 10% / 20% customers (Pareto) and the Gini coefficient |
| `biz_daily_scorecard.sqlx` | The morning table of the board: one row per day with the main KPIs and the right comparisons |
| `biz_executive_weekly_summary.sqlx` | One row per week for the leadership: revenue, orders, conversion, ticket, new customers, WoW and YoY (same week of last year), plus the biggest mover up and down, the number of anomaly alerts and the... |
| `biz_geo_market_penetration.sqlx` | Market penetration per brazilian state (last 365 days): customers and revenue per 100 thousand inhabitants (IBGE Censo 2022) and the index vs Brazil |
| `biz_growth_accounting.sqlx` | Growth accounting per month for users AND customers: new, retained, resurrected (came back after missing a month) and churned (active last month, not this month), plus the Quick Ratio = (new +... |
| `biz_market_size_capture_recapture.sqlx` | How big is the pond? Biologists count the fish of a lake without draining it: catch and tag some, come back later, see how many of the new catch are tagged |
| `biz_monthly_scorecard.sqlx` | Monthly KPIs with MoM and YoY, targets (cfg_targets.js), and for the current month: MTD vs the same days of last month / last year and a weekday weighted projection (a month with 5 saturdays is not a... |
| `biz_opportunity_sizing.sqlx` | Where is the money (last 90 days): for each device x channel x new/returning segment, the revenue we would make if it converted like the best quartile of comparable segments |
| `biz_revenue_bridge.sqlx` | Revenue bridge (waterfall): why revenue changed between two periods, split EXACTLY into traffic effect, conversion effect and ticket (AOV) effect with LMDI decomposition |
| `biz_simpson_paradox_watch.sqlx` | Is the conversion rate really worse, or did the mix change? Last 28 days against the 28 before, for each dimension (device, channel, new x returning, region, landing page type): the change of the... |
| `biz_targets_pacing.sqlx` | Pacing of the current month against the target, day by day: expected cumulative revenue (target spread by the weekday profile of the last weeks), actual cumulative, gap, and the daily revenue needed... |
| `biz_top_movers_weekly.sqlx` | Automatic 'what changed this week': last complete week vs the previous one, for every value of channel, campaign, device, UF, landing page type and browser |
| `biz_unit_economics.sqlx` | Unit economics per month: marketing cost (all cost sources), new customers, blended CAC, revenue of the new customers in 90 days, LTV/CAC with the assumed gross margin and payback in months |

### `definitions/40_marts/cohorts/`

Retention and LTV cohorts.

| file | what it does |
|---|---|
| `coh_ltv_curves.sqlx` | LTV curves: cumulative revenue per acquired user by acquisition month and months since acquisition (0..24), with the share of the cohort that already bought |
| `coh_n_day_retention.sqlx` | Classic N-day retention per daily cohort (last 120 days): D1, D3, D7, D14, D30 'exactly on day N' and the unbounded version 'on day N or later' (what product people usually mean), by first device |
| `coh_repeat_purchase.sqlx` | First purchase cohorts: customers grouped by the month of the first order and how many bought again in each following month, cumulative repeat rate and cumulative revenue per customer (0..12 months) |
| `coh_retention_matrix_wide.sqlx` | The cohort triangle in wide format (one column per week 0..12), ready for a conditional formatting heatmap in Looker Studio / Sheets without any pivot |
| `coh_retention_monthly.sqlx` | Monthly cohorts by acquisition month AND first channel x months since acquisition (0..12): active users, retention, buyers and revenue per cohort user. first_channel = 'all' row has the total of the... |
| `coh_retention_weekly.sqlx` | Weekly cohorts (week of the first visit of the user) x weeks since the first visit (0..12): active users and retention |

### `definitions/40_marts/crm/`

GA4 joined with the backend (optional, `enable_crm`).

| file | what it does |
|---|---|
| `crm_customer_360.sqlx` | Backend customer + GA4 behaviour (joined by user_id): opt-ins, backend lifetime orders and value, GA4 sessions, last visit, channels, lifecycle, RFM, personas and scores |
| `crm_lead_to_customer.sqlx` | Lead to customer (B2B / high ticket / WhatsApp sales): GA4 leads of logged users joined with the backend orders after the lead, by the channel that generated the lead |
| `crm_order_reconciliation.sqlx` | Order by order reconciliation of the last 180 days between GA4 and the backend: matched, missing_in_ga4 (tracking loss: adblock, ITP, consent, thank you page not loaded, boleto paid later)... |
| `crm_tracking_loss.sqlx` | How much of the real business GA4 does not see, by week, payment method and order value bucket (backend side), plus the GA4 orders that do not exist in the backend by browser / hostname |

### `definitions/40_marts/cro/`

Conversion rate optimization and A/B tests.

| file | what it does |
|---|---|
| `cro_ab_test_cuped.sqlx` | A/B tests that finish sooner with the same traffic: CUPED (the variance reduction Microsoft, Netflix and Booking use) removes from the revenue per user of each variant the part already explained by... |
| `cro_ab_test_daily.sqlx` | Cumulative A/B test curves per day and variant (users, conversions, conversion rate, uplift and p value up to that day) |
| `cro_ab_test_results.sqlx` | A/B test analyzer for every experiment in cfg_experiments.js (exposure event in GA4, user level): per variant users, conversions, conversion with Wilson CI, uplift vs control, z-test p value... |
| `cro_ab_test_sequential.sqlx` | The A/B test you ARE allowed to peek at: an 'always valid' p value per day and variant (mixture SPRT, the method of the commercial testing tools), next to the classic one of cro_ab_test_daily |
| `cro_checkout_friction.sqlx` | Checkout friction (last 90 days) by device and payment type: median minutes between checkout steps, steps repeated (people coming back to fix address / payment), payment retries (card declined?) and... |
| `cro_device_gap.sqlx` | Mobile vs desktop gap per landing page type and per top landing pages (last 30 days): conversion of each device, the gap, and the money if mobile converted at least 70% of desktop (a realistic... |
| `cro_empirical_bayes_rates.sqlx` | Conversion rates you can actually rank: the campaign with 2 sales in 9 sessions is not the best of the company |
| `cro_exit_pages.sqlx` | Exit rate per page (last 30 days) with Wilson interval, compared with the median of the same page type |
| `cro_funnel_segment_gaps.sqlx` | Step by step conversion (view -> cart -> checkout -> purchase) for each segment (device, channel, new/returning, browser) vs the whole site, last 30 days, with z-test of each step |
| `cro_landing_pages.sqlx` | Landing pages (last 30 days) by device with engagement, GA4 and UA bounce, conversion with Wilson interval, revenue per session, and the revenue opportunity if the page converted like the median of... |
| `cro_micro_conversion_lift.sqlx` | Micro conversions that predict the macro one (last 30 days): for every event name, purchase rate of sessions that had it vs sessions that did not, lift, phi correlation and coverage |
| `cro_page_influence.sqlx` | Does seeing this page change the conversion? For each page (last 30 days, 200+ sessions): conversion of sessions that saw it vs sessions with the same landing page type that did not, the lift and a... |
| `cro_page_value.sqlx` | UA 'Page Value' resurrected (last 30 days): revenue of the sessions that saw the page BEFORE the purchase, divided by the unique pageviews of the page |
| `cro_session_intent_scores.sqlx` | Purchase intent score (0-100) of the sessions of the last 2 days that did NOT buy, from simple explainable signals (product views, cart, checkout, search, engagement, returning user, logged in) |

### `definitions/40_marts/ecommerce/`

Products, carts, checkout, prices.

| file | what it does |
|---|---|
| `ecom_abandoned_cart_items.sqlx` | Items most left behind in carts (last 30 days): how many carts, value abandoned, users, and the abandonment rate of the item vs its category |
| `ecom_cart_abandonment.sqlx` | Cart abandonment per day / device / channel with the money left in the carts and how much came back: carts recovered = same user purchased within 7 days after the abandoned session (organically or by... |
| `ecom_category_basket_rules.sqlx` | Association rules at category level (last 365 days). Less sparse than items, gives the merchandising team the 'mission' of the baskets (ex: shoes -> socks has lift 4) |
| `ecom_category_brand_daily.sqlx` | Category and brand performance per day (rollup of ecom_item_performance_daily with the CURRENT catalog attributes from dim_items, so renamed categories dont split the history) *(incremental)* |
| `ecom_checkout_behavior.sqlx` | UA 'Checkout Behavior' with the brazilian details: last 90 days, begin checkout -> shipping -> payment -> purchase, split by shipping tier and payment type (boleto, pix, cartao...) |
| `ecom_consideration_time.sqlx` | How long people think before buying, per category: time from the FIRST view of the item (by the same user) to the purchase of it, and how many sessions it took |
| `ecom_coupon_performance.sqlx` | Order coupons (UA 'Order Coupon' report, upgraded): orders, revenue, AOV vs orders without coupon, share of new customers, discount when the items send it, and which channels use each coupon (a... |
| `ecom_daily_kpis.sqlx` | Ecommerce KPIs per day: sessions, buyers, orders, revenue (gross / valid / net of refunds), AOV, conversion, items per order, new x repeat customers, coupon and boleto/pix share *(incremental)* |
| `ecom_freight_shock.sqlx` | The freight shock, state by state: in Brazil the shipping price kills more checkouts than any button color |
| `ecom_item_list_performance.sqlx` | Product list performance (UA 'Product List Performance', GA4 item list reports) with list attribution done right: the last list where the item was clicked in the session gets the add to cart and the... |
| `ecom_item_momentum.sqlx` | The life cycle of every product, read from the demand and not from the sales: launch, rising, stable, declining or dead, comparing the last 14 days of product views with the 14 before and with the 8... |
| `ecom_item_performance_daily.sqlx` | Item funnel per day: list impressions, clicks, detail views, add to cart, checkouts, unique purchases, units, item revenue and refunds, with the UA rates (cart-to-detail, buy-to-detail) and list CTR *(incremental)* |
| `ecom_item_price_changes.sqlx` | Price change log of every item, detected from the prices users saw in GA4 (no ERP needed) |
| `ecom_item_recommendations.sqlx` | Top 10 recommendations per item from two signals: bought together (basket lift) and viewed together in the same session (last 90 days) |
| `ecom_item_switching.sqlx` | Who steals the sale from whom: sessions where the customer opened product A, did not buy it, and bought product B instead (last 90 days) |
| `ecom_list_position_bias.sqlx` | Product lists without the position bias: the first positions are clicked because they are the first, not because the product is good |
| `ecom_market_basket_rules.sqlx` | Market basket analysis (association rules) on the orders of the last 365 days: for item A -> item B, support, confidence and lift |
| `ecom_order_value_distribution.sqlx` | Histogram of order values (last 180 days, R$ 10 buckets up to the p99) with cumulative share and a 'threshold effect' detector: buckets right above a value with way more orders than the bucket below... |
| `ecom_price_elasticity.sqlx` | Price elasticity per item estimated with a log-log regression of daily demand (add to carts and units) on the price users saw, last 365 days |
| `ecom_price_ending_psychology.sqlx` | Does R$ 199,90 really sell more than R$ 200,00 in YOUR store? View to cart and view to purchase rates by the ending of the price the customer saw (,99 / ,90 / ,00 / other, and prices just below a... |
| `ecom_problem_products.sqlx` | Products with traffic and bad conversion (last 30 days): view-to-cart rate way below the category, ranked by the money on the table if they converted like the category median |
| `ecom_refunds_analysis.sqlx` | Refund rate (GA4 refund events) by category, payment type, channel and new x repeat, last 180 days |
| `ecom_repeat_purchase_survival.sqlx` | Kaplan-Meier survival curve of 'time until the second purchase', overall and by first purchase channel |
| `ecom_replenishment_cycles.sqlx` | The clock of each product: for items and categories that people buy again (coffee, pet food, contact lenses, printer ink, diapers), the usual number of days between two purchases of the same... |
| `ecom_shopping_behavior_daily.sqlx` | UA Enhanced Ecommerce 'Shopping Behavior Analysis': all sessions -> with product views -> with add to cart -> with checkout -> with transactions, with the abandonment rates, by day, device, channel... *(incremental)* |
| `ecom_suspected_stockouts.sqlx` | Items that people keep viewing but suddenly nobody adds to cart: probably out of stock (or the buy button / size selector broke) |

### `definitions/40_marts/funnels/`

Generated funnels.

| file | what it does |
|---|---|
| `funnels.js` | Generates, for each funnel of cfg_funnels.js, the steps, daily (open and closed), elapsed time and next action tables, plus fnl_overview (17 actions) |

### `definitions/40_marts/lifts/`

Incrementality.

| file | what it does |
|---|---|
| `lift_activation_holdouts.sqlx` | Real incrementality of the activation (needs cfg_lifts.holdout.enabled): for every audience and every CRM trigger, people that entered after holdout.start_date, split in treated (sent) and holdout... |
| `lift_behaviors_adjusted.sqlx` | Which behaviours go with more purchases, ADJUSTED (last 30 days): for every event, the purchase rate of sessions that did it vs sessions that did not, raw and with the Mantel-Haenszel risk ratio... |
| `lift_interventions.sqlx` | Did the change work? One row per intervention x metric of cfg_lifts.js: post period actual vs counterfactual, lift %, 95% interval, p value, cumulative effect (additive metrics) and a verdict that... |
| `lift_interventions_daily.sqlx` | Day by day of every intervention of cfg_lifts.js (new checkout, redesign, price change, TV...): the actual value of each metric and the counterfactual (what would have happened without the change) |
| `lift_registry.sqlx` | Every lift measured in the project in one table, from the most causal to the least: A/B tests, activation holdouts, geo experiments, interventions and promotions, with the same columns (lift... |

### `definitions/40_marts/marketing/`

Channels, campaigns, media quality.

| file | what it does |
|---|---|
| `mkt_ads_click_reconciliation.sqlx` | Google Ads clicks (gclid by gclid) x GA4 sessions with that gclid. Clicks without session = page did not load, consent denied, tag broken, or click fraud |
| `mkt_ai_assistant_traffic.sqlx` | Traffic from AI assistants (ChatGPT, Perplexity, Gemini, Copilot, Claude, DeepSeek...) by day, assistant and landing page *(incremental)* |
| `mkt_brand_vs_nonbrand_daily.sqlx` | Paid search split in Brand x Non-brand (campaign name or term with brand terms). Brand search mostly 'harvests' demand that other channels created, non-brand creates demand *(incremental)* |
| `mkt_campaign_daily.sqlx` | Daily campaign performance (session scoped, last non-direct click) with new customers and revenue from new customers *(incremental)* |
| `mkt_campaign_fatigue.sqlx` | Creative / campaign fatigue: conversion rate by week of life of each campaign and the trend (slope) of it |
| `mkt_channel_daily.sqlx` | Daily performance by channel (default and custom), source / medium and device. The table behind 80% of the marketing dashboards *(incremental)* |
| `mkt_channel_mix_weekly.sqlx` | Weekly channel mix: share of sessions, new users and revenue of each channel and the change vs the previous week |
| `mkt_channel_overlap.sqlx` | Channel synergy: for each pair of channels, how many users touched both in the last 90 days and how the conversion of those users compares with users that touched only one of them |
| `mkt_channel_return_matrix.sqlx` | Where does each channel send people NEXT? For every session, the channel of the following session of the same person (or '(did not return)' after 30 days of silence), last 180 days |
| `mkt_cookie_churn_inflation.sqlx` | How many of your 'users' are the same person with a new cookie? The logged in customers are the ruler: for each browser, how many GA4 cookies (user_pseudo_id) one known person burned in 90 days on... |
| `mkt_dark_social_estimate.sqlx` | Estimates 'dark social': direct sessions of NEW users landing on deep pages (product, blog, campaign pages) are almost never someone typing the url *(incremental)* |
| `mkt_first_touch_quality.sqlx` | Quality of the acquisition: users grouped by acquisition month and FIRST channel, with conversion and revenue per user after 7 / 30 / 90 days and 30 day return rate |
| `mkt_geo_br_daily.sqlx` | Daily performance by brazilian state (UF), macro region and channel. Shipping cost / delivery time problems in the north and northeast show up here as low conversion *(incremental)* |
| `mkt_in_app_browser_gap.sqlx` | The tax of the in-app browsers: a click on an Instagram, Facebook or TikTok ad opens the site inside the app, in a crippled browser with no saved passwords, no saved cards, no autofill, and a cookie... |
| `mkt_landing_pages_by_channel.sqlx` | Landing page x channel (last 30 days): where each channel sends people and how those pages perform for that channel |
| `mkt_media_heatmap.sqlx` | Weekday x hour heatmap per channel (last 8 weeks): sessions, conversion and revenue index vs the channel average |
| `mkt_media_quality_scorecard.sqlx` | Media quality per source / medium / campaign (last 30 days, campaign as it was TAGGED, so the lost sessions count for the campaign that paid for them): bot share, tagging problems, attribution loss... |
| `mkt_new_vs_returning_daily.sqlx` | New x returning users by day and channel. Returning users usually convert 2-4x more, a 'great' month that was just returning traffic is not growth *(incremental)* |
| `mkt_owned_channels_daily.sqlx` | Owned channels (Email & CRM, SMS & Push, WhatsApp) by campaign and content (the utm_content usually says which link / block of the email) *(incremental)* |
| `mkt_paid_media_performance.sqlx` | Cost (Google Ads, Meta Ads, manual) x GA4 results per day / platform / campaign: CPC, CPA, ROAS, CAC, cost per session and click-to-session rate (tracking loss detector) |
| `mkt_referral_partners.sqlx` | Referral domains (partners, blogs, press, cashback, coupons, marketplaces) last 90 days vs previous 90: sessions, quality and revenue, plus the category of the source |
| `mkt_traffic_bursts.sqlx` | Every sudden burst of visits of the last 30 days, minute by minute and per channel: the e-mail and push blasts (with the exact time they went out and how fast the effect died), the TV spot or the... |
| `mkt_url_tagging_issues.sqlx` | Media quality, the url side (last 30 days): every way a campaign url can lose the attribution, with the utms it had, sessions and revenue affected, an example url, severity and how to fix |
| `mkt_utm_attribution_loss_daily.sqlx` | How much of the tagged traffic GA4 did not attribute, per day and utm source / medium / campaign (last 90 days): tagged sessions, sessions where no event got the source / medium params, sessions GA4... |
| `mkt_utm_linter.sqlx` | UTM hygiene report: upper case, spaces, unknown mediums, source with url, typos ('facebok' -> did you mean 'facebook'?), paid without campaign... with sessions affected and a suggested fix |

### `definitions/40_marts/product/`

Behaviour, content, UX and tech.

| file | what it does |
|---|---|
| `prod_404_broken_links.sqlx` | Broken pages (404 by the page title) of the last 30 days and WHERE people came from: internal page (broken internal link, fix today) or external referrer / campaign (broken ad or backlink, ask for... |
| `prod_active_users_daily.sqlx` | DAU, WAU (7d), MAU (28d) rolling and stickiness (DAU/MAU), with HLL sketches so the rolling distinct users are right and cheap |
| `prod_aha_moments.sqlx` | Aha moment finder: which actions in the FIRST 7 DAYS of a user are most associated with coming back in the following 30 days (and with buying) |
| `prod_app_versions_health.sqlx` | App health by version (Firebase / GA4 app streams, last 30 days): users, sessions, crash events (app_exception fatal), crash free users, engagement and conversion per version |
| `prod_content_engagement.sqlx` | Content performance per page (last 90 days): views, engagement time per view, 90% scroll rate, interactions and the conversion of the sessions that saw the page (plus 7 day assisted purchases for... |
| `prod_feature_adoption.sqlx` | Adoption of the product features (cfg_project.features) in the last 30 days, and how adopters behave vs non adopters: conversion and return rate |
| `prod_form_analytics.sqlx` | Form analytics from enhanced measurement (form_start / form_submit), last 90 days: starts, submits, completion rate and time to submit per form and page |
| `prod_internal_pagerank.sqlx` | PageRank of the site calculated with the REAL navigation of the users (page A -> page B, last 30 days) instead of the links of the html |
| `prod_journey_entropy.sqlx` | Shannon entropy of each user journey (last 90 days): how diverse are the channels and the page types of the user |
| `prod_journey_state_values.sqlx` | The value of every step of the journey (last 60 days): an absorbing Markov chain over the page types gives, for each one, the probability that a session that is THERE NOW ends in a purchase |
| `prod_login_signup_methods.sqlx` | Login and sign up by method (email, google, facebook, apple, whatsapp, gov.br...) last 90 days: events, users, share, and how many of those users bought in the same session |
| `prod_media_and_links.sqlx` | Enhanced measurement in one place (last 90 days): videos (starts, progress, completion), file downloads (by file and extension) and outbound clicks (by domain) |
| `prod_page_transitions.sqlx` | From page -> to page transitions of the last 30 days (next page in the same session, '(exit)' when it was the last one) |
| `prod_path_ngrams.sqlx` | Navigation n-grams (sequences of 2 and 3 page TYPES inside a session, last 30 days) with how often they happen and the conversion of sessions that contain them |
| `prod_post_purchase_behavior.sqlx` | What happens AFTER the thank you page, where every GA4 report stops: in the 30 days after each order, did the customer come back, how many times did they open the order tracking, did they go to the... |
| `prod_power_user_curve.sqlx` | Power user curve (L28, the a16z one): of the users active in the last 28 days, how many were active 1 day, 2 days ... 28 days |
| `prod_search_content_gaps.sqlx` | What customers want and you dont have (or they cant find): search WORDS (stopwords in portuguese removed) with many searches, high exit / zero results and few product views after |
| `prod_search_reformulations.sqlx` | The synonym dictionary the customers write for free: pairs of searches made one right after the other in the same session, without clicking a product in between (last 90 days) |
| `prod_session_timeout_splits.sqlx` | Visits that GA4 cut in two because of the 30 minute timeout (lunch, a phone call, the boleto being paid in the bank app): sessions that start shortly after the previous one of the same device ended |
| `prod_site_search_terms.sqlx` | Site search (UA 'Site Search Terms' style, last 90 days): normalized term (no accents, lower), searches, unique searches, % search exits, % refinements, product views after the search, conversion of... |
| `prod_tech_performance.sqlx` | Browser x OS x device combos (last 30 days) with engagement and conversion compared to the device average |
| `prod_time_to_value.sqlx` | Time to value: from the first visit to the first occurrence of each key event (median, p75, p90 in days, and how many sessions it took), by first channel |
| `prod_top_session_paths.sqlx` | Most common session journeys (first 5 page types, consecutive repeats collapsed), last 30 days, with sessions, conversion and revenue per session |
| `prod_traffic_load_profile.sqlx` | GA4 as a capacity planning tool: per day, the busiest minute (events, page views and sessions active at the same time), the percentiles of the minute load and how far the peak is from a normal minute *(incremental)* |
| `prod_ux_friction_signals.sqlx` | UX friction signals per page (last 30 days) that GA4 does not show anywhere: ping-pong navigation (A > B > A > B, user lost), rage reloads (same page again in < 10s), quick backs (left in < 5s to the... |
| `prod_web_vitals.sqlx` | Core Web Vitals from GA4 (web-vitals library sending LCP / CLS / INP / FCP / TTFB as events, cfg_project.web_vitals) by page type and device, last 28 days: p75 like Google uses, share good / needs... |

### `definitions/40_marts/promotions/`

Promotions and coupons.

| file | what it does |
|---|---|
| `promo_calendar_lift.sqlx` | For each promotion of the calendar (cfg_promotions.js): daily averages before (baseline), during and after, the lift during the promo and the 'pull forward' dip after it |
| `promo_coupon_codes_usage.sqlx` | Coupons of the promotion calendar: orders inside the promo window and OUTSIDE it (coupon that keeps working after the end = margin leak), plus coupons used that are not in the calendar at all |
| `promo_coupon_hijacking.sqlx` | Last click hijacking by cashback / coupon sites: the user was ALREADY in the checkout, left, came back through Meliuz / Cuponomia / Pelando & co and bought within 24h |
| `promo_discount_depth.sqlx` | Discount depth vs results (last 365 days): orders bucketed by % of discount (item discount param), with AOV, new customer share and the repeat rate in 90 days of the customers acquired in each bucket |
| `promo_halo_effect.sqlx` | Halo effect of internal promotions (last 90 days): in sessions that clicked a promotion, how much was spent on items that were NOT part of the promotion, vs sessions that did not click |
| `promo_internal_promotions_daily.sqlx` | Internal promotions (banners, sliders, menu highlights): views, clicks, CTR by promotion / creative / slot per day, and the revenue of the sessions that clicked (GA4 'Promotions' report + UA... *(incremental)* |
| `promo_seasonal_scorecard.sqlx` | Retail dates scorecard (Black Friday, Black Week, Cyber Monday, Dia das Maes, Dia dos Namorados, Dia dos Pais, Dia das Criancas, Natal, Dia do Consumidor, 11.11...) year by year, with the change vs... |

### `definitions/40_marts/segments/`

User segmentations (one row per user_key, personal data).

| file | what it does |
|---|---|
| `seg_category_affinity.sqlx` | Category affinity per user (last 90 days), TF-IDF style: interest in the category (view 1, cart 3, purchase 5 points) divided by the user total, times how rare the category is among all users |
| `seg_cross_device.sqlx` | Cross device behaviour of the logged users (UA had a Cross Device report, GA4 has nothing): device mix per user, where they discover (first session device) and where they buy (device of the purchases) |
| `seg_engagement_and_value_tiers.sqlx` | Two tiers per user: engagement tier (last 30 days: active days, engaged time and views, percentile based) and value tier (lifetime revenue: top_1_pct, top_5_pct, top_10_pct, top_25_pct, rest... |
| `seg_lifecycle.sqlx` | Current lifecycle stage of every user (prospects and customers): new_visitor, engaged_prospect, dormant_prospect, first_time_customer, repeat_customer, loyal_customer, at_risk_customer... |
| `seg_lifecycle_transitions.sqlx` | Lifecycle as a Markov chain: stage of each customer at the end of every month (last 12 months) and the transition matrix month to month with probabilities |
| `seg_personas.sqlx` | Behavioral personas (last 90 days, rule based so everybody understands them): bargain_hunter, window_shopper, serial_cart_abandoner, researcher, impulse_buyer, loyalist, content_reader, app_lover... |
| `seg_price_sensitivity.sqlx` | Price sensitivity of each customer (last 365 days): price of what they look at vs price of what they buy (relative to the category median), share of orders with coupon / discount. premium_buyer... |
| `seg_rfm.sqlx` | RFM of every customer (valid purchases, last 2 years): recency, frequency, monetary, quintile scores and the classic named segments (Champions, Loyal, Potential Loyalist, New, Promising, Need... |
| `seg_segment_overlap.sqlx` | GA4 'Segment overlap' exploration for our own segments: for every pair of segment values (lifecycle stage, RFM segment, persona, value tier, engagement tier, price profile) how many users are in... |
| `seg_time_of_day_profiles.sqlx` | When each user is usually online (last 90 days, 2+ sessions): madrugada / manha / tarde / noite and weekday x weekend |
| `seg_user_profile_360.sqlx` | Everything we know about each user in one row: identity, acquisition, lifetime numbers, RFM, lifecycle, persona, engagement and value tiers, top categories, preferred daypart, price profile and... |
| `seg_visit_rhythm.sqlx` | The habit of each user, one row per user_key (last 180 days): burstiness of the visits (clockwork, random or in bursts, the Goh-Barabasi index used to study human behaviour), favourite weekday and... |

### `definitions/40_marts/seo/`

Organic search (most need `enable_search_console`).

| file | what it does |
|---|---|
| `seo_content_decay.sqlx` | Content decay: landing pages losing organic traffic. Last 28 days vs previous 28 and vs the same 28 days last year, plus the weekly trend (OLS slope of the last 12 weeks) |
| `seo_ctr_opportunities.sqlx` | Query + page pairs (last 28 days) with CTR below the expected CTR for their position, where expected = the site's OWN median CTR per position (not a generic industry curve) |
| `seo_landing_pages_gsc.sqlx` | Search Console x GA4 per landing page (last 28 days): Google impressions, clicks, CTR and position next to the GA4 organic sessions, engagement and revenue |
| `seo_organic_daily.sqlx` | Organic search per day, search engine, landing page and device (session own source, no carry over: this is what organic really brought that day) *(incremental)* |
| `seo_query_cannibalization.sqlx` | Keyword cannibalization (last 28 days): queries where 2+ pages of the site split the impressions and none of them dominates |

### `definitions/50_reports/ga4_ui/`

Replicas of the GA4 interface (bots kept, to match the UI).

| file | what it does |
|---|---|
| `ga4_dimension_reports.js` | Generates the GA4 standard reports as daily incremental tables: traffic and user acquisition, demographics, tech, and friends (5 actions) |
| `rpt_ga4_engagement_overview_daily.sqlx` | GA4 Reports > Engagement > Overview per day: average engagement time, engaged sessions per user, views, events, plus DAU / WAU / MAU and stickiness (DAU/MAU, DAU/WAU, WAU/MAU) *(view)* |
| `rpt_ga4_events_daily.sqlx` | GA4 Reports > Engagement > Events: event count, total users, event count per user and value per event name and platform, per day *(incremental)* |
| `rpt_ga4_key_events_daily.sqlx` | GA4 Reports > Engagement > Key events: count, users and value of each key event (cfg_key_events.js, GA4 counting method applied) by session channel and device, per day *(incremental)* |
| `rpt_ga4_landing_and_journeys.js` | GA4 landing page report and the purchase / checkout journey reports of Monetization (3 actions) |
| `rpt_ga4_monetization_views.js` | GA4 Monetization reports (ecommerce purchases, promotions, coupons...) as views over the marts with the GA4 column names (3 actions) |
| `rpt_ga4_overview_last_28_days.sqlx` | The GA4 home cards (last 28 days vs the 28 before): active users, new users, sessions, engagement rate, average engagement time, events, key events and revenue, with the change *(view)* |
| `rpt_ga4_pages_and_screens_daily.sqlx` | GA4 Reports > Engagement > Pages and screens: page path / screen, title, views, users, views per user, average engagement time per user, event count, entrances and exits per day *(incremental)* |
| `rpt_ga4_path_exploration.sqlx` | GA4 Explorations > Path exploration, for every session at once (last 30 days): the first 5 steps of the session as page titles AND as event names (consecutive repeats collapsed, like GA4 does), with... |
| `rpt_ga4_realtime.sqlx` | GA4 Realtime (needs include_intraday): last 30 minutes straight from the streaming export, per minute, with country, page, event, source and platform *(view)* |
| `rpt_ga4_retention_overview.sqlx` | GA4 Reports > Retention, the 4 cards in one long table: new vs returning users per day, user retention by days since first visit (day 0..42), engagement per user by cohort day, and lifetime value per... |
| `rpt_ga4_user_explorer.sqlx` | GA4 Explorations > User explorer: the timeline of a stitched user (all devices) in the last 30 days, one row per user with the sessions and the events in order *(view)* |
| `rpt_ga4_user_lifetime.sqlx` | GA4 Explorations > User lifetime: users grouped by first user source / medium / campaign (stitched users) with average lifetime revenue, sessions, engaged sessions, engagement time, transactions and... |

### `definitions/50_reports/universal_analytics/`

Universal Analytics reports rebuilt on GA4 data.

| file | what it does |
|---|---|
| `rpt_ua_active_users_daily.sqlx` | UA Audience > Active Users: 1-day, 7-day, 14-day and 28-day active users for every day (rolling, HLL merged) |
| `rpt_ua_all_pages_daily.sqlx` | UA Behavior > Site Content > All Pages per day: pageviews, unique pageviews, avg time on page (UA formula: time on page / (pageviews - exits)), entrances, bounce rate of the entrances and % exit *(incremental)* |
| `rpt_ua_behavior_flow.sqlx` | UA Behavior Flow (last 30 days): starting page -> 1st interaction -> 2nd -> 3rd, with sessions that went through each node and the drop-offs at every step, for the top 50 landing pages |
| `rpt_ua_bounce_rate_comparison.sqlx` | The 'why did our bounce rate drop after GA4' table (last 90 days): UA bounce (1 page, no interaction) vs GA4 bounce (not engaged) per landing page and channel, and the sessions that explain the gap... |
| `rpt_ua_content_views.js` | UA content reports (Content Drilldown, Landing Pages, Exit Pages...) as views over rpt_ua_all_pages_daily (2 actions) |
| `rpt_ua_conversion_views.js` | UA Conversions reports (Goals, Ecommerce, Multi-Channel Funnels) as views over the marts with the UA names (5 actions) |
| `rpt_ua_coupons_and_affiliates.sqlx` | UA Conversions > Ecommerce > Marketing per month: Order Coupon Code, Product Coupon Code and Affiliate Code with transactions, revenue and avg order value |
| `rpt_ua_engagement_buckets.sqlx` | UA Audience > Behavior > Engagement (last 30 days): sessions and pageviews by Session Duration buckets (0-10s, 11-30s, 31-60s, 61-180s, 181-600s, 601-1800s, 1801+) and by Page Depth (1..20+) |
| `rpt_ua_events_daily.sqlx` | UA Behavior > Events with Category / Action / Label: uses the UA style params when the site still sends them (cfg_project.ua_event_params, very common after migrations), otherwise category = event... *(incremental)* |
| `rpt_ua_frequency_recency.sqlx` | UA Audience > Behavior > Frequency & Recency (last 30 days): sessions and pageviews by 'Count of Sessions' and by 'Days Since Last Session', with the exact UA buckets |
| `rpt_ua_lifetime_value.sqlx` | UA Audience > Lifetime Value: users acquired per month and acquisition channel, with what they did in the first 7 / 30 / 90 days (revenue, transactions, views, goal completions, sessions, engagement... |
| `rpt_ua_navigation_summary.sqlx` | UA Behavior > Site Content > Navigation Summary (last 30 days): for every page, where people came from (previous page path, '(entrance)') and where they went next (next page path, '(exit)'), top 10... |
| `rpt_ua_reverse_goal_path.sqlx` | UA Conversions > Goals > Reverse Goal Path (last 30 days): for each key event (goal), the page where it happened and the 3 pages before it, with completions |
| `rpt_ua_site_search_overview_daily.sqlx` | UA Behavior > Site Search > Overview per day (last 90 days): sessions with search, total and unique searches, results pageviews / search, % search exits, % search refinements, time after search and... |
| `rpt_ua_time_to_purchase.sqlx` | UA Conversions > Ecommerce > Time to Purchase (transactions of the last 90 days): days to transaction (from the first visit of the user) and sessions to transaction (ga_session_number of the purchase... |
| `ua_dimension_reports.js` | Generates the UA Audience / Acquisition / Behavior reports as daily incremental tables with UA metrics and the original UA channel grouping (12 actions) |

### `definitions/60_data_science/btyd/`

Buy Till You Die: BG/NBD + Gamma-Gamma fitted in BigQuery.

| file | what it does |
|---|---|
| `ds_btyd_customer_clv.sqlx` | Per customer: probability of still being 'alive', expected purchases in the next 13 weeks, expected order value (Gamma-Gamma) and the CLV of the period (revenue and gross margin) |
| `ds_btyd_model_params.sqlx` | BG/NBD (purchase / dropout process) and Gamma-Gamma (spend) fitted INSIDE BigQuery by maximum likelihood with the JS UDFs fit_bg_nbd / fit_gamma_gamma |
| `ds_btyd_summary.sqlx` | RFM summary in the 'buy till you die' format (lifetimes style): x = repeat purchase days, t_x = time between first and last purchase, T = customer age, in weeks (cfg_ds.btyd.time_unit_days) |

### `definitions/60_data_science/churn_ltv/`

BQML churn and LTV (`enable_bqml`).

| file | what it does |
|---|---|
| `ds_model_churn.sqlx` | BQML classifier for customers: probability of NOT coming back in the next 30 days (cfg_ds.churn) *(model)* |
| `ds_model_ltv.sqlx` | BQML regressor: revenue of the user in the next 90 days (predicted LTV). Only snapshots old enough to have the 90 day label *(model)* |
| `ds_scores_churn.sqlx` | Churn risk (no session in the next 30 days) of every active customer today, BQML model, with risk band |
| `ds_scores_ltv.sqlx` | Predicted revenue of the next 90 days for every active user (BQML regressor), with LTV decile |

### `definitions/60_data_science/clustering/`

BQML k-means (`enable_bqml`).

| file | what it does |
|---|---|
| `ds_model_user_clusters.sqlx` | BQML k-means over the behaviour of the active users (standardized). Data driven segments to put next to the rule based personas *(model)* |
| `ds_user_clusters.sqlx` | Cluster of each active user (k-means) and the profile of every cluster (size and average of each feature), so somebody can give them human names |

### `definitions/60_data_science/features/`

Feature store and scores without ML.

| file | what it does |
|---|---|
| `ds_feature_snapshots.sqlx` | Feature store for the predictive models: one row per user per weekly snapshot (cfg_ds.features), features ONLY from before the snapshot and labels ONLY from after (no leakage) |
| `ds_heuristic_scores.sqlx` | Purchase propensity and churn risk WITHOUT machine learning: every user of today gets the historical rate of 'users like him' (same profile of cart / checkout / recency / customer history) in the... |

### `definitions/60_data_science/forecasting/`

BQML ARIMA_PLUS (`enable_bqml`).

| file | what it does |
|---|---|
| `ds_kpi_forecast.sqlx` | Forecast of the next 90 days for sessions, orders and revenue (ARIMA_PLUS) with prediction intervals, plus the actuals of the last 90 days in the same shape (row_type actual / forecast) so the chart... |
| `ds_kpi_forecast_anomalies.sqlx` | ML.DETECT_ANOMALIES of the ARIMA_PLUS model over the history (holiday aware). Same shape of the other anomaly methods, it enters anom_ensemble as one more vote when enable_bqml is on |
| `ds_model_kpi_forecast.sqlx` | BQML ARIMA_PLUS, one series per KPI (sessions, orders, revenue), with brazilian holidays (holiday_region = BR) and automatic seasonality *(model)* |

### `definitions/60_data_science/missions/`

Shopping missions (labs).

| file | what it does |
|---|---|
| `ds_shopping_missions.sqlx` | The unit GA4 does not have: the shopping mission. A session is too small (nobody buys a sofa in one visit) and a user is too big (the same person buys a sofa in march and socks in june) |
| `ds_shopping_missions_summary.sqlx` | The economics of the shopping missions per month and opening channel: mission conversion rate (the real one: 'of the times somebody came to buy something, how many bought'), sessions and days a... |

### `definitions/60_data_science/mmm/`

Marketing mix model, lite (`enable_bqml`).

| file | what it does |
|---|---|
| `ds_mmm_contributions.sqlx` | Contribution of each platform to the revenue per month according to the MMM (weight x saturated adstock), spend, and the incremental ROAS of the model |
| `ds_mmm_dataset.sqlx` | Daily dataset for a lightweight Marketing Mix Model: revenue, spend per platform with geometric adstock (carry over of the ads effect, decay in cfg_ds.mmm) and log saturation (diminishing returns)... |
| `ds_model_mmm.sqlx` | Lightweight MMM: BQML linear regression of daily revenue on the saturated adstock of each platform + calendar controls *(model)* |

### `definitions/60_data_science/propensity/`

BQML purchase propensity (`enable_bqml`).

| file | what it does |
|---|---|
| `ds_model_purchase_propensity.sqlx` | BQML classifier: probability of purchase in the next 7 days. Trained on the weekly snapshots, the newest training snapshot is kept OUT (out of time holdout, used by ds_propensity_gains) *(model)* |
| `ds_model_purchase_propensity_evaluation.sqlx` | Evaluation of the propensity model (ML.EVALUATE: precision, recall, accuracy, f1, log loss, ROC AUC) and the top features (ML.GLOBAL_EXPLAIN), in one table |
| `ds_propensity_gains.sqlx` | Gains / lift table of the propensity model on the out of time holdout (newest training snapshot, never seen in training): purchase rate per decile, lift vs average and cumulative share of buyers... |
| `ds_scores_purchase_propensity.sqlx` | Purchase propensity (next 7 days) of every active user today, from the BQML model, with decile (10 = most likely) |

### `definitions/60_data_science/risk/`

Order risk signals (labs).

| file | what it does |
|---|---|
| `ds_order_risk_signals.sqlx` | A review queue for suspicious orders built only with behaviour GA4 already has (last 90 days): many orders from the same device in 24 hours, payment retries, a brand new device buying something... |

### `definitions/60_data_science/statistics/`

Statistics in plain SQL.

| file | what it does |
|---|---|
| `ds_category_transitions.sqlx` | Next best category: Markov chain of the purchase journey (main category of order k -> main category of order k+1, last 2 years) |
| `ds_daily_metrics_wide.sqlx` | One row per day (last 400 days) with the main KPIs AND the sessions of every channel as columns |
| `ds_event_cooccurrence.sqlx` | Which events happen together in the same session (last 30 days, top 40 events): co-occurrence count, lift and phi correlation for every pair |
| `ds_geo_experiment_did.sqlx` | Geo experiments by brazilian state (cfg_experiments.geo_experiments): difference-in-differences of daily revenue and sessions between test UFs and control UFs, pre vs test period, plus the pre period... |
| `ds_lagged_correlations.sqlx` | Cross correlation between the sessions of each channel and the revenue N days LATER (lag 0..14, last 365 days, both detrended with 7 day differences) |
| `ds_metric_correlations.sqlx` | Correlation matrix of the daily metrics (last 365 days): Pearson (linear) and Spearman (rank, robust to outliers and non linear monotonic relations) for every pair |
| `ds_search_term_ngrams.sqlx` | Text mining of the site search (last 90 days): unigrams and bigrams of the normalized terms (no accents, portuguese stopwords removed), with searches and the conversion of the sessions |
| `ds_survival_first_purchase.sqlx` | Kaplan-Meier of 'time from the first visit to the first purchase' (days 0..90), overall and by first channel, with censoring for users that did not have time yet |

### `definitions/70_monitoring/anomaly_detection/`

Anomaly detection: 8 methods, ensemble, root cause, alerts.

| file | what it does |
|---|---|
| `anom_alert_feed.sqlx` | Ready to send alerts of the last 3 days (severity medium+), one line each, with a human message and the main root cause. tools/alerts/send_alerts.py reads this table and posts to Slack / Google Chat... |
| `anom_cusum.sqlx` | Method 6 - two sided tabular CUSUM (JS UDF) over the z-scores of the last 120 days (56 day baseline) |
| `anom_ensemble.sqlx` | The judge: joins the 8 detection methods (+ BQML ARIMA_PLUS when enable_bqml) and raises an alert only when enough of them agree |
| `anom_ewma.sqlx` | Method 5 - EWMA forecast (exponentially weighted moving average, lambda 0.3): recent days weigh more, so it adapts to trends |
| `anom_hourly_intraday.sqlx` | Near real time check (needs include_intraday): today, hour by hour, sessions / purchases / revenue vs the same hour of the same weekday in the last 4 weeks |
| `anom_iqr.sqlx` | Method 4 - Tukey fences: outside Q1 - k*IQR .. Q3 + k*IQR of the previous 56 days (k = 1.5) |
| `anom_level_shift.sqlx` | Method 8 - level shift / change point: Welch t statistic between the last 7 days (ending on the day) and the 28 days before them |
| `anom_mad.sqlx` | Method 3 - robust modified z-score (Iglewicz & Hoaglin): median and MAD of the previous 56 days |
| `anom_metric_series_daily.sqlx` | Daily time series monitored by the anomaly detection (cfg_anomaly.js): metric x breakdown (all, device, channel, platform), long format |
| `anom_root_cause.sqlx` | Automatic root cause of the alerts of the last 7 days (property level, additive metrics): for every dimension of cfg_anomaly.root_cause_dimensions, which values explain the change vs the same weekday... |
| `anom_same_weekday.sqlx` | Method 2 - z-score against the SAME WEEKDAY of the previous 8 weeks. Mondays compared with mondays |
| `anom_spc_nelson_rules.sqlx` | Method 7 - Statistical Process Control, Nelson rules over the z-scores (56 day baseline), the same rules factories use since the 80s: 1 point beyond 3 sigma, 9 in a row on the same side, 6 in a row... |
| `anom_zscore.sqlx` | Method 1 - classic z-score against the previous 28 days (mean and standard deviation, current day excluded) |

### `definitions/70_monitoring/data_quality/`

Data quality of the export and of the tracking.

| file | what it does |
|---|---|
| `dq_benford_purchase_values.sqlx` | Benford's law test on the purchase values of the last 365 days (first digit) |
| `dq_bot_traffic_daily.sqlx` | Bot traffic per day, channel, source / medium and campaign (last 90 days): sessions, bot sessions (session or device signals), sessions of devices classified as bots, the top signals and the... |
| `dq_completeness_daily.sqlx` | Completeness checks per day (last 60 days), long format: share of events / sessions / purchases missing something important (session id, page_location, session_start, transaction_id, revenue, items... |
| `dq_daily_volumes.sqlx` | Raw volumes of the export per day and platform (events, devices, sessions, page views, purchases, cookieless, internal, debug, duplicates) straight from staging, before any business filter *(incremental)* |
| `dq_data_trust_index_daily.sqlx` | Data Trust Index: one number (0-100) per day that says how much the data of that day can be trusted |
| `dq_double_tagging_pages.sqlx` | Pages where page_view fires twice in less than 1 second (last 14 days) |
| `dq_duplicates_daily.sqlx` | Duplicates per day (last 60 days): exact duplicated rows in the export, purchases sent more than once (thank you page reload), and page views fired twice in less than 1 second (double tagging: gtag +... |
| `dq_event_naming_hygiene.sqlx` | Event naming problems of the last 90 days: names out of snake_case, case variants of the same event ('Add_To_Cart' x 'add_to_cart', GA4 treats as 2 events) and NEAR duplicates by edit distance... |
| `dq_export_freshness.sqlx` | Is the GA4 export alive? One row with the latest daily shard, hours since it was created, missing days in the last 30, latest intraday, and the status (ok / late / broken) |
| `dq_ga4_limits_violations.sqlx` | Things that break GA4 collection limits (last 7 days): event names over 40 chars, param names over 40, param values hitting 100 chars (GA4 cuts them, silently), events with more than 25 params, user... |
| `dq_hostname_governance.sqlx` | Every hostname that sent data in the last 30 days: expected production host, non production (staging, localhost, vercel previews, google translate proxy, web archive) or unknown (ghost spam / someone... |
| `dq_identity_resolution.sqlx` | How well we know who is who (devices active in the last 90 days): devices, people and dedup rate per identity method (login, linked by order, linked by ad click, merged anonymous, device only)... |
| `dq_item_catalog_consistency.sqlx` | Catalog consistency as seen by GA4 (last 30 days): item_id with many names or categories, items without category / brand, same name with different ids, and items whose price jumps a lot inside the... |
| `dq_not_set_diagnostics.sqlx` | Why sessions end up as 'Unassigned' or with landing page '(not set)' (last 30 days), with the most common raw source / medium behind each reason |
| `dq_param_cardinality.sqlx` | Cardinality of every event param (last 7 days): distinct values per day, top value share and type mix |
| `dq_referral_hygiene.sqlx` | Referrals we threw away (payment gateways, 3DS pages, own domains) in the last 30 days, with sessions and revenue that would have been credited to them |
| `dq_scorecard_daily.sqlx` | All the data quality checks of all the DQ tables in one place (check date x check), with group, value, thresholds, status and weight |
| `dq_session_quality_daily.sqlx` | Row level quality summed up per day (last 90 days): bot suspect share, average data quality score of the sessions, share of trusted sessions and how often each quality issue and each bot signal... |
| `dq_source_shards.sqlx` | Every shard of the GA4 export (daily, intraday, fresh) with row count, size, when it was created and last modified, the export delay and the late rewrites |
| `dq_tracking_blackouts.sqlx` | Blackouts: stretches of minutes with ZERO events in a stream at an hour of the week that always has traffic (last 14 days) |
| `dq_tracking_breaks.sqlx` | Events that died or collapsed: compared the last 3 complete days with the 28 days before, per event and platform |
| `dq_tracking_integrity.sqlx` | Tracking integrity per day (last 30 days): logic of the ecommerce funnel (purchase without begin_checkout, add_to_cart without view_item, checkout without cart), device clock skew and Measurement... |
| `dq_ui_vs_bigquery_explainer.sqlx` | 'Why does BigQuery not match the GA4 screen?', answered with numbers instead of a shrug |
| `dq_validity_daily.sqlx` | Validity checks per day (last 60 days): invalid currency codes, negative or absurd revenue, items with zero price in purchases, crazy quantities, timestamps outside the event date, user_id that looks... |

### `definitions/70_monitoring/ga4_change_watch/`

What changed in the export and in the tracking, with dates.

| file | what it does |
|---|---|
| `watch_attribution_drift.sqlx` | Our default channel group against the one GA4 itself exports (session_traffic_source_last_click), per day: agreement rate, the top disagreements and a drift flag |
| `watch_dimension_values.sqlx` | Memory of every value ever seen for the dimensions that should not change much (hostnames, streams, app versions, currencies, payment types, shipping tiers, browsers, OS, countries, languages, event... *(incremental)* |
| `watch_event_registry.sqlx` | Every event name ever seen, with first / last day, volume of the last 7 days against the 4 weeks before, and a status (new, gone, dropping, spiking, stable) |
| `watch_export_schema_by_shard.sqlx` | Schema of every daily shard of the GA4 export (field path + type), from INFORMATION_SCHEMA. Google changes the export without telling anyone (session_traffic_source_last_click in jul/2024, batch_*... |
| `watch_export_schema_changes.sqlx` | Every change of the GA4 export schema, shard against the previous shard: fields added, removed and leaf fields that changed type |
| `watch_export_streams.sqlx` | Every data stream (web / app) in the export: first and last day, events of the last 7 days against the 7 before and status |
| `watch_item_param_registry.sqlx` | Custom item params (items.item_params, the 'item scoped custom dimensions') seen in the last 90 days, per event: types, distinct values, items with it, first / last day and status |
| `watch_new_values.sqlx` | Values seen for the first time in the last 7 days (new hostname = site clone / scraper / new subdomain, new app_version = release, new currency or payment type = someone changed the checkout...) *(view)* |
| `watch_param_registry.sqlx` | Every event x param pair seen in the last 120 days (stg_ga4__event_params keeps 120): types it arrived with, fill rate in the last 7 days, first / last day and status. type_drift = sometimes string... |
| `watch_tracking_changelog.sqlx` | One feed with everything that changed in the GA4 data (last 90 days): export schema, events, params, user properties, item params, new hostnames / streams / app versions / currencies, streams that... |
| `watch_user_property_registry.sqlx` | Every user property seen: types, approximate distinct values, devices with it in the last 7 days, first / last day and status (new / gone / type_drift / ok) |

### `definitions/70_monitoring/governance/`

Event dictionary, tracking plan, custom definitions.

| file | what it does |
|---|---|
| `gov_custom_definitions_inventory.sqlx` | Which params and user properties deserve to be GA4 custom dimensions / metrics, and if they fit the quota (standard property: 50 event scoped dimensions, 25 user scoped, 10 item scoped, 50 metrics) |
| `gov_event_dictionary.sqlx` | The living event dictionary: every event that really arrives (not the one in the confluence page from 2021), with description, owner, key event config, status, volume, devices and every param it... |
| `gov_tracking_plan_coverage.sqlx` | Is the tracking plan implemented? One row per planned event x param: event seen in 7 / 28 days, fill rate of the param, type as planned or not, items present when the plan asks for items, and the... |
| `gov_tracking_plan_violations.sqlx` | Daily violations of the tracking plan (last 30 days): unplanned events (when allow_unplanned_events = false), required params missing or empty, params with the wrong type, ecommerce events without... |
| `gov_url_parameter_inventory.sqlx` | Every query string parameter that ever showed up in a page url (last 30 days), with how often, how many different values, an example, where it appears and what it is: campaign tag, click id of an ad... |

### `definitions/70_monitoring/pipeline_ops/`

Operation of the pipeline itself.

| file | what it does |
|---|---|
| `ops_bootstrap_datasets.sqlx` | Creates every dataset of the project (IF NOT EXISTS). UDFs and the watermark table need the dataset before CREATE *(operation)* |
| `ops_incremental_watermarks.sqlx` | Log of every incremental run (model, run_from, mode). Downstream models read it to follow upstream backfills automatically *(operation)* |
| `ops_job_costs.sqlx` | What each model costs: BigQuery jobs of the last days that wrote into our datasets (the Dataform runs), per destination table and day, with bytes billed, slot hours, estimated on demand USD and... |
| `ops_pipeline_freshness.sqlx` | Did last night run? Per incremental model: last load, last run_from, mode, runs in 7 days and how late it is |
| `ops_table_inventory.sqlx` | Every table and view the project created, with rows, logical / physical size, time travel bytes, partitions, last change and hours since it |
| `ops_table_usage.sqlx` | Who really uses what: for every table / view of the project, how many queries read it in the last days (outside the pipeline), how many different people, last read and the tables nobody touches... |

### `definitions/70_monitoring/privacy_lgpd/`

LGPD controls.

| file | what it does |
|---|---|
| `priv_activation_consent_audit.sqlx` | Proof that the activation layer only sends consented people: for every act_ table, rows, distinct users and the rows of users that are NOT allowed for that destination today (must be zero)... |
| `priv_consent_by_channel_daily.sqlx` | Ads consent per channel and day (sessions) |
| `priv_consent_by_page.sqlx` | Consent per page (page views of the last 30 days) |
| `priv_consent_daily.sqlx` | Consent Mode health per day, platform, hostname and device: analytics_storage / ads_storage granted vs denied vs unknown, cookieless pings, the CMP params (ad_user_data, ad_personalization) and the... *(incremental)* |
| `priv_data_inventory.sqlx` | ROPA-lite (registro das operações de tratamento, LGPD art. 37) made from BigQuery itself: every table and view of the project + the raw GA4 export, with size, last change, which personal data it... |
| `priv_dsr_access_report.sqlx` | What we have about each person that asked for access / confirmation / portability (LGPD art. 18 I, II and V): activity, devices, where they came from, purchases, consent, user properties and the... |
| `priv_dsr_deletion.sqlx` | LGPD deletion (art. 18 VI) of the approved requests: deletes the rows of every device / user_id / user_key of the request from all user level tables of the project, logs it in priv_dsr_deletion_log... *(operation)* |
| `priv_dsr_deletion_log.sqlx` | Audit log of the LGPD deletions: which table, how many rows, for which requests and when *(operation)* |
| `priv_dsr_deletion_preview.sqlx` | Dry run of the LGPD deletion, always on: for the approved deletion requests, how many rows each table would lose *(operation)* |
| `priv_dsr_identifiers.sqlx` | Every identifier of each data subject request: the user_id (raw and the SHA256 form staging uses when the id looked like email/CPF), every device (user_pseudo_id) that ever logged in with it, and the... |
| `priv_dsr_requests.sqlx` | Data subject requests (titulares, LGPD art. 18) with SLA, what we found for each one and where the deletion is |
| `priv_dsr_suppression_list.sqlx` | People whose data was deleted (LGPD art. 18 VI). Staging reads it and drops their events, so a full refresh never brings them back from the raw export *(operation)* |
| `priv_lgpd_scorecard.sqlx` | The DPO page: every LGPD check of today in one table (consent mode health, PII leaks, user_id, data subject requests SLA, inventory, masking, retention, activation only with consent), same format as... |
| `priv_pii_findings.sqlx` | PII scanner on the RAW GA4 export (before our masking): every string event param, user property, user_id and the manual campaign fields of the last pii_scan_days, checked for email, CPF, CNPJ, phone... *(incremental)* |
| `priv_pii_summary.sqlx` | One row per leak (field x kind of PII) with status (active / intermittent / fixed / new), when it started, volume in the last 7 days and what to do about it |
| `priv_retention_log.sqlx` | Audit log of the retention purge (data_retention_months): what was deleted / dropped, with which cutoff and when *(operation)* |
| `priv_retention_preview.sqlx` | Dry run of the retention purge, always on: per user level table, the oldest date it has and how many rows are older than data_retention_months *(operation)* |
| `priv_retention_purge.sqlx` | Retention purge (LGPD art. 15 and 16: personal data cannot live forever): deletes rows older than data_retention_months from every user level table of the project *(operation)* |
| `priv_user_id_quality.sqlx` | user_id quality per day (raw export, last pii_scan_days): ids that are email / CPF / phone in clear text (LGPD), too long, placeholders ('undefined', 'null', '0', 'guest'... a classic dataLayer bug... |

### `definitions/80_activation/`

Payloads for ad platforms and CRM, gated by consent.

| file | what it does |
|---|---|
| `act_audience_exports.sqlx` | Audience lists ready per destination (only the destinations allowed in cfg_audiences): google_ads (Customer Match, hashed e-mail / phone, needs enable_crm), meta (Custom Audiences: external_id +... |
| `act_consent_eligible_users.sqlx` | The gate of the activation layer: one row per user with the latest consent and what can be done with them (ads platforms, GA4 write back, CRM) |
| `act_crm_triggers.sqlx` | CRM triggers to send today: act_crm_triggers_all without the holdout group. This is the one the CRM / automation tool reads (e-mail / WhatsApp opt-ins are checked on the CRM side) *(view)* |
| `act_crm_triggers_all.sqlx` | Every CRM trigger of today (identified customers that can_send_to_crm), INCLUDING the holdout group (cfg_lifts.holdout): abandoned checkout, abandoned cart (with the items), price drop on a product... |
| `act_crm_triggers_history.sqlx` | Daily snapshot of the CRM triggers (holdout included, flagged): who got which trigger on which day *(incremental)* |
| `act_crm_user_traits.sqlx` | Reverse ETL for the CRM / CDP (Salesforce, HubSpot, RD Station...): one row per identified customer (user_id) with what the site knows and the CRM does not: lifecycle, RFM, value and engagement... |
| `act_ga4_mp_user_properties.sqlx` | Write back to GA4 with the Measurement Protocol: our traits (RFM, lifecycle, value tier, propensity band, CLV decile) as user properties of the device, so they show up in GA4 audiences, explorations... |
| `act_google_ads_offline_conversions.sqlx` | Google Ads offline conversion import (last 90 days): every valid key event of a consented user, matched to the LAST Google Ads click of the user (gclid, gbraid or wbraid) in the 90 days before it... |
| `act_meta_capi_events.sqlx` | Meta Conversions API events of the last 7 days (Meta refuses events older than 7 days): key events of consented users mapped to the Meta standard names (cfg_key_events meta_event_name), event_id for... |

### `definitions/90_assertions/`

Checks that fail the run.

| file | what it does |
|---|---|
| `assertions_core.js` | Assertions of the core layer: no placeholder or giant users, uniqueness of the keys, reconciliation between core, marts and reports (9 actions) |
| `assertions_lgpd.js` | LGPD assertions: no PII after staging, activation only with consent, DSR inside the SLA, deleted people stay deleted (5 actions) |
| `assertions_marts.js` | Assertions of the marts: attribution credits sum to one, closed funnels never grow, and other math that must hold (5 actions) |

### `analyses/`

Ready queries for the day to day. Not compiled by Dataform.

| file | what it does |
|---|---|
| `01_why_did_revenue_drop.sql` | Revenue bridge, top movers and anomaly root cause for the 'why is revenue down?' question |
| `02_channels_last_30_days.sql` | Channel performance of the last 30 days for the weekly marketing meeting |
| `03_landing_pages_to_fix.sql` | Landing pages with traffic and bad conversion, ranked for the CRO backlog |
| `04_products_with_problems.sql` | Problem products, suspected stockouts and price changes for the merchandising meeting |
| `05_is_this_difference_real.sql` | Examples of the statistics UDFs (z-test, Wilson, Bayes, Welch) to check a difference before announcing it |
| `06_one_user_journey.sql` | Every session, page and event of one user, for support and product investigations |
| `07_who_to_call_today.sql` | Valuable customers going away (CLV x P(alive)) and the CRM triggers of the day |
| `08_tracking_health_monday.sql` | Monday checklist of the analytics team: data trust index, tracking breaks, changelog, tracking plan violations |
| `09_month_pacing.sql` | Month to date against the targets and the forecast of the month end |
| `10_utm_mess.sql` | UTM problems per campaign, ready to send to the agency |
| `11_media_quality.sql` | Bots, broken campaign urls and lost attribution per campaign |
| `12_what_really_works.sql` | Every lift measured (holdouts, A/B tests, interventions, promotions) by level of evidence |
| `13_what_was_that_spike.sql` | Labs: traffic bursts with probable cause, tracking blackouts and the peak load of each day |
| `14_merchandising_moves.sql` | Labs: products to promote / demote in the lists, hidden gems, substitutes and replenishment reminders of the week |
| `15_who_broke_the_habit.sql` | Labs: regular users late for their own rhythm and the open shopping missions with money on the table |
| `16_is_the_number_real.sql` | Labs: mix vs rate (Simpson), shrunk rates, 'can I stop the A/B test', UI vs BigQuery differences and cookie inflation |
| `README.md` | Index of the ready queries of this folder and when to use each one |

### `docs/`

Documentation.

| file | what it does |
|---|---|
| `activation.md` | How the activation tables work (Google Ads offline conversions, Meta CAPI, Measurement Protocol, CRM) and how to send them |
| `anomaly_detection.md` | The 8 anomaly methods, the ensemble vote, the root cause and the alert feed |
| `architecture.md` | The flow of the layers, the rules every model follows, the incremental strategy, tags, schedules and naming |
| `attribution.md` | Touchpoints, the 7 rule based models, Markov, Shapley and how to read them side by side |
| `catalog.md` | Generated by tools/generate_catalog.js: every action of the project by dataset with its description (do not edit by hand) |
| `configuration.md` | Every var of workflow_settings.yaml and every includes/cfg_*.js file explained |
| `data_contracts.md` | Grain and columns of the core tables, the contract the marts read |
| `data_fixes.md` | Every correction made on top of the export and the column that flags it |
| `data_science.md` | Feature store, heuristic scores, BQML models, BTYD, MMM-lite and the statistics tables |
| `identity_and_bots.md` | How devices become people (login + identity graph) and how bots are scored per session and per device |
| `labs.md` | The labs models: the question each one answers, the math in short and the limits |
| `lgpd.md` | Consent monitoring, PII scanner, data subject requests, deletion, retention and the DPO scorecard |
| `lifts.md` | Holdouts, interventions, adjusted behaviours and the lift registry with the level of evidence |
| `media_quality.md` | Campaign url problems, attribution loss and the media quality scorecard |
| `metrics_glossary.md` | Definition of every metric (sessions, users, engagement, revenue...) and how it compares with GA4 and UA |
| `report_mapping.md` | Which table replaces each GA4 and Universal Analytics report |
| `runbook.md` | How to run it: first run, schedules, backfills, full refresh, what to do when something fails |
| `troubleshooting.md` | Known errors of the first runs (missing columns, permissions, heavy marts) and how to fix them |

### `tools/`

Dev tools (not part of the Dataform project).

| file | what it does |
|---|---|
| `generate_catalog.js` | Writes docs/catalog.md from the compiled graph |
| `package.json` | Dev scripts: compile, validate:sql, test:udfs, check, catalog, alerts:dry-run (lives here because Dataform does not allow a package.json in the root) |
| `validate_sql.py` | Parses every compiled statement with sqlglot (BigQuery dialect) plus a lint for what a parser accepts and BigQuery refuses |

### `tools/tests/`

Tests of the JS UDFs.

| file | what it does |
|---|---|
| `test_js_udfs.js` | Tests of the JS UDFs: CPF, CNPJ, Luhn, url decode, Bayes, BG/NBD, Gamma-Gamma, Markov, Shapley, CUSUM |
| `test_labs_udfs.js` | Tests of the labs UDFs: PageRank, absorbing Markov values and a simulation of the sequential test against daily peeking |

### `tools/alerts/`

Alert sender.

| file | what it does |
|---|---|
| `send_alerts.py` | Reads the alert tables in BigQuery and posts to Slack, Google Chat, Teams and / or e-mail |
