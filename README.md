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
| `01_udfs` | 47 persistent functions for the pipeline and the analysts: params, urls, channel grouping, PII (CPF / CNPJ alfanumérico / Luhn), stats (normal CDF, Wilson, z-test, Bayes, Welch, chi-square), BG/NBD, Gamma-Gamma, Markov, Shapley, CUSUM, brazilian calendar |
| `02_seeds` | reference tables from the configs (UF + IBGE 2022, pt stopwords, tracking plan, promotions, targets...) |
| `10_staging` | `stg_ga4__events` (dedup, PII masking, export fixes, auto backfill when Google rewrites shards, LGPD suppression), items, params, user properties + other sources |
| `20_intermediate` | sessions, traffic source (last non-direct carry over, gclid / payment gateway / self referral fixes), bot score per session AND per device (impossible travel, cron like visits, credential stuffing...), page views with time on page, identity graph (login + same order + same ad click) with retroactive stitching, campaign url checks, deduplicated transactions, key events, costs |
| `30_core` | `fct_sessions` (row level data quality score), transactions, items, key events, user daily + dims (users, items, pages, campaigns, calendar BR). Contract in `docs/data_contracts.md` |
| `40_marts` | marketing (21, with media quality: url tagging problems, attribution loss, campaign scorecard), attribution (13: 7 rule models + Markov + Shapley + MCF), lifts (5: activation holdouts, interventions, adjusted behaviour lift, registry), ecommerce (20), promotions (7), product (20), business (14), CRO (11, with A/B analyzer), SEO (5), funnels (generated), cohorts (6), segments (11), audiences (generated), CRM (4) |
| `50_reports` | 21 GA4 UI replicas and 32 Universal Analytics reports rebuilt on GA4 data (Behavior Flow, Navigation Summary, Reverse Goal Path, Content Drilldown, MCF, Time to Purchase...) |
| `60_data_science` | feature store without leakage, heuristic scores, BQML (propensity + gains, churn, LTV, k-means, ARIMA_PLUS with BR holidays, MMM-lite), BTYD fitted inside BigQuery, correlations, lagged correlations, Kaplan-Meier, geo DiD, search n-grams |
| `70_monitoring` | data quality (22 tables + Data Trust Index, identity resolution, bot traffic), anomaly detection (8 methods + ensemble + root cause + alert feed), LGPD (19: consent, PII scanner on the raw export, DSR access / deletion with suppression list, retention, inventory, scorecard), GA4 change watch (11: export schema timeline, event / param / user property / item param registries, new values, channel drift, streams, changelog), governance (living event dictionary, tracking plan coverage and violations, custom definitions vs quota), ops (inventory, job costs, table usage, freshness) |
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

## docs

`docs/architecture.md` · `docs/configuration.md` · `docs/runbook.md` · `docs/data_contracts.md` ·
`docs/metrics_glossary.md` · `docs/data_fixes.md` · `docs/attribution.md` ·
`docs/anomaly_detection.md` · `docs/data_science.md` · `docs/lgpd.md` · `docs/activation.md` ·
`docs/report_mapping.md` · `docs/identity_and_bots.md` · `docs/media_quality.md` · `docs/lifts.md` · `docs/troubleshooting.md` · `docs/catalog.md` (generated: every
action with its description) · `analyses/` (queries for the day to day) · `CONTRIBUTING.md`

## status (honest)

- 467 actions: 386 tables / views / incrementals, 62 operations (47 UDFs, 6 BQML models, LGPD and
  bootstrap ops), 19 assertions. Compiles with every module off and every module on, 0 syntax
  problems in the 759 statements (sqlglot + lint), JS UDF tests green.
- **It was never run against a real BigQuery.** The validator checks syntax, not your schema: the
  first run will probably find a column name that your export does not have (see
  `docs/troubleshooting.md`), a permission missing for INFORMATION_SCHEMA / JOBS, or a mart that
  needs a smaller `mart_window_days`. Run it first in a dev project, with `start_date` close to today.
- The LGPD deletion and retention operations are OFF by default and must stay off until the DPO
  validates the preview tables. Nothing in this project sends data outside BigQuery: the
  activation tables are payloads, the sending is your job (`docs/activation.md`).
- Not legal advice. The LGPD layer helps to comply, it does not make anyone compliant by itself.
