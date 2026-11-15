<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# troubleshooting

The problems that already happened (to me or to people I know), and the fix.

## compile

**`var "start_date" must look like YYYY-MM-DD`**: the vars are strings, `start_date: 2024-01-01`
without quotes is parsed by YAML as a date. Use quotes.

**A module turned on by itself**: some var was compared as a string somewhere. Always use
`constants.ENABLE.x`, never `dataform.projectConfig.vars.x` in a model.

**`package.json` not allowed**: Dataform 3 does not accept a `package.json` in the root together
with `dataformCoreVersion`. The dev tools live in `tools/`.

## BigQuery errors

**`Unrecognized name: session_traffic_source_last_click`** (or `collected_traffic_source`,
`is_active_user`, `batch_event_index`...): your export is older than the column, or the newest
shards are from an export that was paused. Wildcard queries use the schema of the newest table.
Fix: in `includes/ga4.js`, `RAW_EVENT_COLUMNS`, replace the name by a typed NULL with the same
name, ex:

```js
`CAST(NULL AS STRUCT<
   cross_channel_campaign STRUCT<campaign_id STRING, campaign_name STRING, source STRING, medium STRING,
                                 default_channel_group STRING, primary_channel_group STRING>,
   google_ads_campaign STRUCT<customer_id STRING, account_name STRING, campaign_id STRING, campaign_name STRING,
                              ad_group_id STRING, ad_group_name STRING>
 >) AS session_traffic_source_last_click`,
```

(only the fields staging reads are needed, these are all of them; the `ga4_session_*` columns
become NULL and our own traffic logic keeps working). Columns and dates: `collected_traffic_source`
may/2023, `is_active_user` jul/2023, `batch_*` oct/2023, `session_traffic_source_last_click`
jul/2024. `watch_export_schema_changes` shows when each one appeared in YOUR export.

**`Cannot GROUP BY literal values`**: the validator lint catches it (`npm run check`), fix the
GROUP BY to use the real columns.

**`Access Denied: ... INFORMATION_SCHEMA.JOBS_BY_PROJECT`**: `ops_job_costs` / `ops_table_usage`
need `bigquery.jobs.listAll` (role BigQuery Resource Viewer). Without it, disable those two.

**Region errors in INFORMATION_SCHEMA**: the region views use `defaultLocation`
(`region-us`, `region-southamerica-east1`...). The project datasets and the GA4 export must be in
the same location, BigQuery does not join across locations.

**`Query exceeded resource limits` in path / basket marts**: lower `mart_window_days`.

## numbers

**Sessions differ from the GA4 UI by more than ~3%**:
1. internal / debug traffic: the UI may not filter what we filter (`exclude_*` vars);
2. GA4 thresholds and consent modeling: the UI shows modeled users, the export does not;
3. `rpt_ga4_*` uses the GA4 session definition, the core counts sessions with `session_start` OR
   any event with `ga_session_id` (GA4 also does that, but the UI estimates with HLL);
4. timezone: `property_timezone` must be the same of the property.

**Revenue differs from the backend**: `crm_order_reconciliation` (with `enable_crm`) shows order by
order: tracking loss (`crm_tracking_loss`), cancelled, unpaid boleto / PIX, duplicated purchases.

**Too much (not set) / Unassigned**: `dq_not_set_diagnostics` and `mkt_utm_linter` tell you why
(missing utm_medium, unknown source, gclid without auto tagging...).

**Direct is huge**: `mkt_dark_social_estimate`, `dq_referral_hygiene` (payment gateways and self
referrals stealing the source) and `int_ga4__session_traffic.is_carried_over`.

**Users of 7 / 28 days do not sum**: they never do, users are distinct. Use the HLL sketches
(`HLL_COUNT.MERGE(users_hll)`) to merge days.

## pipeline

**An incremental is late** (`ops_pipeline_freshness`): look at the Dataform run log; the
watermark is only written when the post operation runs, so a failed run does not move it.

**Full refresh of staging was done, the marts look weird**: after a full refresh of staging,
full refresh everything. The watermarks follow backfills of up to `auto_backfill_max_days`, a full
reload is too big to follow.

**BQML training too expensive**: `cfg_ds.features.training_snapshots` lower, or `enable_bqml`
off (heuristic scores keep audiences working).
