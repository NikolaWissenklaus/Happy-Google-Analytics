<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# architecture

How the thing is put together, and why. If you only read one doc, read this one.

## the flow

```
 GA4 BigQuery export (events_*, events_intraday_*, users_*)      Google Ads / Meta / GSC / CRM / costs
            |                                                              |
            v                                                              v
 00_sources   declarations only, nothing is created here
 01_udfs      47 persistent functions (also for the analysts, not only for the pipeline)
 02_seeds     reference tables generated from includes/cfg_*.js
            |
 10_staging   stg_ga4__events: dedup, PII masking, export fixes, auto backfill
            |   + items, params (long format), user properties, other sources
            v
 20_intermediate   sessions, traffic source with carry over, bot score (session + device), page views,
            |      identity graph + stitching, url tagging checks, deduplicated transactions, key events, costs
            v
 30_core      fct_sessions / fct_transactions / fct_key_events / fct_user_daily + dims
            |   (THE contract: docs/data_contracts.md)
            v
 40_marts     marketing (+ media quality), attribution, lifts, ecommerce, promotions, product, business, CRO, SEO,
 50_reports   funnels, cohorts, segments, audiences, CRM | GA4 UI + Universal Analytics replicas
 60_data_science   features, BQML, BTYD, MMM, statistics
            |
 70_monitoring  data quality, anomaly detection, LGPD, GA4 change watch, governance, ops
 80_activation  Google Ads, Meta CAPI, GA4 Measurement Protocol, CRM (consent gated)
 90_assertions  the run fails when something that must be true is not
```

One dataset per layer / context (`<schema_prefix>_<layer>`, ex: `ga4_marketing`). This is on
purpose: BigQuery permissions are per dataset, so marketing reads `ga4_marketing` and
`ga4_reports`, the DPO reads `ga4_privacy`, nobody outside data engineering reads `ga4_staging`.

## rules that every model follows

- **Business rules only in `includes/cfg_*.js`.** Key events, funnels, audiences, channel rules,
  promotions, targets, tracking plan, LGPD settings. Models read the config, they never hardcode
  "purchase" or "google / cpc".
- **Vars only through `includes/constants.js`.** Dataform gives every var as a string, and
  `"false"` is truthy. `constants.js` parses them once, the models use `constants.X`.
- **Nothing breaks when an optional module is off.** `enable_*` vars set `disabled:` and the JS
  ternaries remove the joins, so the project compiles with every combination (`check.sh` and
  `check_all_on.sh` validate both extremes).
- **Fix, but flag.** When we change something the export says (traffic source rescued by gclid,
  payment gateway referral removed, duplicated purchase dropped, user_id hashed...) there is a
  column saying so. See `docs/data_fixes.md`.
- **Bots are flagged, not deleted.** Core keeps everything with `is_bot_suspect`. Business marts
  drop them (`exclude_bots_in_marts`), GA4 / UA replica reports keep them like the UI does.
- **Dates in the property timezone** (`property_timezone`), never UTC. `event_date` of the
  export already is, our timestamps are converted when they become dates.
- **Users are counted with HLL sketches** where a report is aggregated by day, so 7/28 day users
  can be merged without double counting (`HLL_COUNT.MERGE`).

## incremental strategy (the part that took longer)

GA4 rewrites daily shards after we read them: late hits up to 72h, and sometimes a full
reprocessing weeks later. A plain "last 3 days" incremental silently misses that.

1. `stg_ga4__events` reads `__TABLES__` of the export and finds the shards modified after its
   last load (`shards_changed_from`). It reloads from the oldest changed shard (capped by
   `auto_backfill_max_days`) or from `lookback_days`, whatever is older.
2. Every incremental model writes its `run_from` in `ga4_ops.ops_incremental_watermarks`
   (`helpers.incrementalPostOps`).
3. Downstream incrementals read the watermarks of their upstreams
   (`helpers.incrementalPreOps({ upstream: [...] })`) and reprocess from the same date when an
   upstream went back in time. Backfills propagate by themselves, no manual full refresh.
4. Pattern is DELETE + INSERT by partition (`DELETE FROM self WHERE date >= run_from`), not MERGE:
   cheaper and idempotent.

Tables that depend on the whole history of a user (dims, `fct_sessions`, identity) are rebuilt
every run from the incremental intermediates, so identity and flags are always retroactive.

## tags and schedules

| tag | when | what |
|---|---|---|
| `bootstrap` | once (and it is harmless daily) | datasets, watermarks table, LGPD logs / suppression list |
| `daily` | every day after the export lands (GA4 usually finishes the daily shard by ~9h BRT) | almost everything |
| `weekly` | sunday | BQML training (propensity, churn, LTV, clusters, ARIMA, MMM) |
| `hourly` | if `include_intraday` | realtime view and intraday anomaly checks |
| `assertions` | after daily | data contract checks, see `definitions/90_assertions` |
| `lgpd`, `activation`, `ga4_watch`... | | context tags, to run one area alone |

## naming

| prefix | layer |
|---|---|
| `stg_<source>__<thing>` | staging (one per source table) |
| `int_<source>__<thing>` | intermediate |
| `fct_` / `dim_` | core |
| `lift_` | lifts (holdouts, interventions, adjusted behaviours, registry) |
| `mkt_` `attr_` `ecom_` `promo_` `prod_` `biz_` `cro_` `seo_` `fnl_` `coh_` `seg_` `aud_` `crm_` | marts by area |
| `rpt_ga4_` / `rpt_ua_` | report replicas |
| `ds_` | data science |
| `dq_` `anom_` `priv_` `watch_` `gov_` `ops_` | monitoring |
| `act_` | activation |
| `assert_` | assertions |

CTE names are plain english that says what it does (`remove_duplicates`, `last_click_before`,
`filtra_usuarios_que_...` would also be fine, but we kept english). If a CTE needs a comment to be
understood, the name is wrong.

## where the code lives

| folder | what |
|---|---|
| `includes/constants.js` | vars, datasets, flags |
| `includes/helpers.js` | incremental pre/post ops, filters, date helpers, seeds |
| `includes/ga4.js` | param extraction, url parsing, raw export columns, event id |
| `includes/channels.js` | GA4 default channel group (same order as Google) + custom grouping |
| `includes/privacy.js` | PII regex, masking, detection, DSR / retention SQL builders |
| `includes/tagging.js` | structural checks of campaign urls (media quality) |
| `includes/lifts.js` | holdout rules shared by activation and lift measurement |
| `includes/metrics.js`, `reports.js` | session metrics and the report builder of 50_reports |
| `includes/cfg_*.js` | the business rules |
| `tools/` | validator, UDF tests, catalog generator, alert sender |
| `analyses/` | ready queries for the day to day (not compiled by Dataform) |
