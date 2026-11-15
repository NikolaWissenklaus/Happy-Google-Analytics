<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# configuration

Two places: `workflow_settings.yaml` (infra and switches) and `includes/cfg_*.js` (business rules).
Change the yaml first, compile, then go through the cfg files with someone from the business.

## workflow_settings.yaml

Every var is a string (`"true"`, `"30"`). `includes/constants.js` parses them.

| var | default | what |
|---|---|---|
| `defaultProject` / `defaultLocation` | | where the datasets are created. Location must be the same of the GA4 export dataset |
| `ga4_project` / `ga4_dataset` | | the export (`analytics_<property id>`) |
| `property_timezone` | America/Sao_Paulo | same timezone of the GA4 property |
| `property_currency` | BRL | reporting currency of the property |
| `site_hostnames` | | your real hostnames, comma separated. Self referrals, hostname checks and "new hostname" alerts use it |
| `start_date` | 2024-01-01 | first day loaded on a full refresh |
| `lookback_days` | 3 | days reprocessed on every incremental run (GA4 late hits) |
| `auto_backfill_max_days` | 30 | how far back a shard rewrite by Google can pull the incremental |
| `include_intraday` | false | read `events_intraday_*` for the days without daily shard (realtime, hourly anomalies) |
| `exclude_internal_traffic` / `exclude_debug_traffic` | true | drop `traffic_type` internal and DebugView traffic from sessions onwards |
| `mask_pii_in_urls` | true | mask e-mail / CPF / CNPJ / phone / sensitive url keys in staging, hash PII looking user_id |
| `exclude_bots_in_marts` | true | business marts without bot suspects (core keeps them flagged) |
| `mart_window_days` | 400 | history of the heavy marts (baskets, paths...) |
| `session_lookback_days` | 90 | last non-direct carry over window (GA4 uses 90) |
| `conversion_lookback_days` | 30 | attribution path lookback |
| `time_decay_half_life_days` | 7 | time decay model (GA4 used 7) |
| `attribution_channel_grouping` | default | `default` (GA4 compatible) or `custom` (our grouping with AI, WhatsApp, brand...) |
| `schema_prefix` | ga4 | datasets become `<prefix>_<layer>` |
| `enable_bqml` | false | BigQuery ML models (cost: training is weekly) |
| `enable_google_ads` + project / dataset / customer_id | false | Google Ads Data Transfer tables |
| `enable_meta_ads` + project / dataset / table | false | Meta insights table (any connector) |
| `enable_search_console` + project / dataset | false | Search Console bulk export |
| `enable_crm` + project / dataset / tables | false | backend orders and customers |
| `enable_user_export` | false | GA4 user data export (`pseudonymous_users_*`) |
| `enable_dsr_deletion` | false | LGPD deletion of approved requests. **Destructive** |
| `enable_retention_purge` | false | delete user level rows older than `data_retention_months`. **Destructive** |
| `data_retention_months` | 26 | retention for the purge and the inventory |
| `pii_scan_days` | 7 | days of raw export scanned for PII every day |
| `dsr_table` | "" | `project.dataset.table` with the data subject requests. Empty = `cfg_privacy.data_subject_requests` |
| `dsr_include_raw_export` / `retention_include_raw_export` | false | the LGPD ops also touch the raw export. Read `docs/lgpd.md` |

## includes/cfg_*.js

| file | what you configure | who should look at it |
|---|---|---|
| `cfg_project.js` | brand terms, internal traffic types, test orders, deferred payments (boleto / PIX paid rate), max realistic order, margin, bot rules (session and device level), page types, 404 titles, features, web vitals, UA params, BigQuery price | data + business |
| `cfg_key_events.js` | key events, value rules, Google Ads conversion names, Meta event names | marketing |
| `cfg_funnels.js` | funnels (steps, scope, window) | product / CRO |
| `cfg_audiences.js` | audiences, conditions, destinations, consent needed | CRM / media |
| `cfg_channels.js` | sources by group, AI assistants, payment gateways, cashback, WhatsApp, aliases | marketing |
| `cfg_tracking_plan.js` | events, params, types, required, naming rules, descriptions | analytics + dev |
| `cfg_privacy.js` | sensitive url keys, consent params of the CMP, user_id rules, DSR SLA, dataset classification | DPO |
| `cfg_identity.js` | placeholder user_ids, shared account limit, identity graph links (order, ad click) and their limits | data |
| `cfg_lifts.js` | activation holdouts (off by default), interventions to measure, behaviour lift settings | marketing + CRO |
| `cfg_promotions.js` | commercial calendar (Black Friday, Dia das Mães...) | promotions |
| `cfg_targets.js` | monthly targets | business |
| `cfg_costs.js` | manual costs (influencers, offline, anything without API) | marketing |
| `cfg_experiments.js` | A/B tests and geo experiments | CRO |
| `cfg_anomaly.js` | metrics watched, breakdowns, thresholds | data |
| `cfg_ds.js` | features, models, horizons | data science |
| `seeds_br.js` | UFs with IBGE population, stopwords | rarely |

## before production (checklist)

- [ ] `site_hostnames` with every real hostname (checkout too)
- [ ] key events of `cfg_key_events.js` = key events marked in the GA4 admin
- [ ] internal traffic rule created in GA4 admin and the value in `cfg_project.internal_traffic_types`
- [ ] test order pattern (`test_transaction_patterns`) matches how QA places orders
- [ ] payment gateways of your checkout in `cfg_channels.payment_gateways`
- [ ] CMP consent params in `cfg_privacy.consent_params` (or leave the defaults, they are ignored when missing)
- [ ] DPO read `docs/lgpd.md` and decided retention and the DSR flow
- [ ] service account with BigQuery Data Editor on the project, Data Viewer on the export dataset,
      Job User, and `bigquery.jobs.listAll` if you want `ops_job_costs` / `ops_table_usage`
- [ ] `cd tools && npm install && npm run check` green
