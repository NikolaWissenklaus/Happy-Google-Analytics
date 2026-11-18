<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# runbook

The day to day of the pipeline.

## first run

1. Fill `workflow_settings.yaml` and the `cfg_*.js` (see `docs/configuration.md`).
2. `cd tools && npm install && npm run check` must be green.
3. In Dataform (GCP) or the CLI: run the tag `bootstrap` (datasets, watermarks, LGPD logs).
4. Run everything with full refresh once. With 2 years of a mid size e-commerce expect some
   minutes for staging and the rest goes fast. Check `ops_job_costs` the day after.
5. Schedule:
   - `daily` every day after the export (GA4 finishes the daily shard around 9h BRT, schedule at 10h);
   - `assertions` right after;
   - `weekly` on sunday (BQML training, only with `enable_bqml`);
   - `weekly` also refreshes 6 heavier `insights` models (`docs/insights.md`): schedule it even without `enable_bqml`;
   - `hourly` every hour (only with `include_intraday`);
   - `tools/alerts/send_alerts.py` after the assertions.

## every morning (5 minutes)

1. `ops_pipeline_freshness`: everything loaded? (`is_late`)
2. `dq_data_trust_index_daily`: trust index of yesterday. Below 70, read `failing_checks` before
   sending any number to the board.
3. `anom_alert_feed`: the alerts (they also arrive in Slack).
4. `watch_tracking_changelog` where `severity = 'critical'`: did a deploy break the tracking?

## every monday

- `watch_tracking_changelog` (all of it), `gov_tracking_plan_violations`, `priv_pii_summary`,
  `priv_lgpd_scorecard`, `ops_table_usage` (tables nobody reads: switch off).
- `mkt_media_quality_scorecard` and `mkt_url_tagging_issues` (send to the agency), `dq_bot_traffic_daily`.

## common tasks

| task | how |
|---|---|
| new key event | `cfg_key_events.js`, compile, run `daily`. Key events are rebuilt every run, no backfill needed |
| new funnel / audience | `cfg_funnels.js` / `cfg_audiences.js`. The tables are generated (`fnl_<name>_*`, `aud_<name>`) |
| new channel rule | `cfg_channels.js`. `int_ga4__session_traffic` is incremental: full refresh it (and the downstream incrementals follow by the watermarks) |
| Google rewrote old shards | nothing, staging finds them in `__TABLES__` and the watermarks propagate (up to `auto_backfill_max_days`) |
| backfill older than `auto_backfill_max_days` | full refresh of `stg_ga4__events`, then full refresh of everything (`docs/architecture.md`) |
| new optional module | turn the `enable_*` var on, compile, run with full refresh only the new actions (`--actions` / tags) |
| LGPD request | add it to the DSR table, the DPO sets `approved`, the next run does the rest. Close it (`done`) after `priv_dsr_requests.pipeline_status = deleted_waiting_closure` |
| model changed the grain / columns of an incremental | full refresh that model (and its downstream incrementals) |
| measure a change (new checkout, redesign, TV) | add it to `cfg_lifts.interventions` (the start date can be in the past), read `lift_interventions` |
| start measuring the activation for real | agree the % with marketing, `cfg_lifts.holdout.enabled = true` and `start_date` = today |
| identity looks wrong (a "user" with 300 devices) | `dq_identity_resolution`, then `cfg_identity.js` (placeholders, limits, link types) |

## when something breaks

See `docs/troubleshooting.md`. Golden rule: never "fix" a number in a mart. Fix the rule in the
config or the bug in the layer where it was born, and let it propagate.
