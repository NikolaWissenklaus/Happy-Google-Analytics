<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# LGPD

What the project does for the LGPD (Lei 13.709/2018), how the destructive parts work and what
is still on you. This is not legal advice: show this page to your DPO (encarregado) and let them
decide the switches.

## privacy by design (always on)

| what | where |
|---|---|
| PII masked before leaving staging: e-mail, CPF, CNPJ (alfanumérico too), phone, sensitive url keys (`?email=`, `?cpf=`, `?token=`...) | `stg_ga4__events`, `includes/privacy.js`, `mask_pii_in_urls` |
| user_id that looks like e-mail / CPF replaced by SHA256 | `stg_ga4__events.user_id_was_hashed` |
| CRM e-mail and phone only hashed (Google and Meta formats), clear text stays in the CRM | `stg_crm__customers` |
| one dataset per context, so access can be given per area | `constants.SCHEMAS` |
| activation only for people with consent, nothing leaves without passing the gate | `act_consent_eligible_users` |
| privacy tables never store the PII they find (masked examples only, no hashes of CPF: 10^9 possibilities is nothing for a laptop) | `privacy.maskForSample` |

## monitoring (daily)

| table | question |
|---|---|
| `priv_consent_daily` | consent rates per day / platform / hostname / device, cookieless pings, CMP params, `consent_mismatch_events` (cookie after a denied consent) |
| `priv_consent_by_page` | pages where the banner looks broken or missing |
| `priv_consent_by_channel_daily` | ads consent per channel, revenue the ad platforms do not see |
| `priv_pii_findings` | PII in the RAW export (every string param, user property, user_id, manual UTMs), last `pii_scan_days` |
| `priv_pii_summary` | one row per leak, status (new / active / fixed) and how to fix |
| `priv_user_id_quality` | user_id as e-mail / CPF / phone, placeholders ('undefined', 'null'...), shared ids |
| `priv_data_inventory` | ROPA-lite (art. 37) generated from BigQuery: every table, its personal data, legal basis, retention, mismatches with `cfg_privacy.dataset_classification` |
| `priv_activation_consent_audit` | proof that every activation table only has allowed people |
| `priv_lgpd_scorecard` | all of the above as checks, with the LGPD score. The DPO page |

Assertions `assert_activation_only_consented_users`, `assert_no_clear_pii_in_staging`,
`assert_user_id_is_not_pii_after_staging`, `assert_dsr_requests_within_sla` and
`assert_deleted_people_stay_deleted` fail the run when the rule breaks.

## data subject requests (art. 18)

Requests come from `dsr_table` (production) or `cfg_privacy.data_subject_requests` (tests).
Columns: `request_id, request_type, user_id, user_pseudo_id, requested_at, status`.

- `request_type`: access | confirmation | portability | correction | deletion | anonymization | revocation
- `status`: open -> approved (by the DPO) -> done | rejected

```
priv_dsr_identifiers      user_id (raw + the hashed form of staging) -> every device that ever logged in
        |                 with it (int_ga4__user_id_pairs_daily) -> user_key of core
        +--> priv_dsr_requests        SLA (cfg_privacy.dsr_sla_days, 15 by default, art. 19), what was found,
        |                             pipeline_status, is_overdue
        +--> priv_dsr_access_report   access / confirmation / portability: what we have about the person
        +--> priv_dsr_deletion_preview  dry run: rows per table that the deletion would remove
        +--> priv_dsr_deletion          (enable_dsr_deletion) the real thing
```

Revocation, deletion and anonymization requests block the person in the activation gate the day
they arrive, even before approval.

### how the deletion works

Only requests with `status = approved`, during 4 days after the first run (GA4 rewrites shards up
to 72h later):

1. the ids of the request go to `priv_dsr_suppression_list` as SHA256 (the id itself is not kept);
2. every BASE TABLE of the project with `user_pseudo_id`, `user_id`, `user_key` or `session_key`
   (found in INFORMATION_SCHEMA, so new tables are covered without code) loses the rows of the
   person (privacy, seeds and ops datasets are skipped: the request is a legal record);
3. each table, rows and run go to `priv_dsr_deletion_log` (your proof for the ANPD);
4. `stg_ga4__events` (and the user export) drops anything in the suppression list on every load,
   so a full refresh never brings the person back.

Aggregated tables keep their numbers: aggregated data is not personal data (art. 12).

### what it does NOT do (read this)

- **The raw GA4 export.** The GA4 User Deletion API deletes from GA4, not from BigQuery. With
  `dsr_include_raw_export = true` the deletion also runs DELETE on every `events_*`,
  `events_intraday_*`, `pseudonymous_users_*` and `users_*` shard. Without it, the raw dataset
  still has the person (our tables do not). Use the GA4 User Deletion API too, for the GA4 side.
- **BigQuery time travel / fail-safe.** Deleted rows stay recoverable for up to 7 days (time
  travel, `max_time_travel_hours` of the dataset can make it 2 days) plus 7 days of fail-safe
  (only Google can restore). Tell the titular "deleted, backups expire in up to 14 days".
- **Other copies.** Exports, spreadsheets, BI extracts, ad platforms. Activation stops sending the
  person, but what was already sent must be removed in each platform.

## retention (art. 15 and 16)

`priv_retention_preview` (always on) shows, per user level table, the oldest date and how many
rows are older than `data_retention_months`, plus the raw shards. With
`enable_retention_purge = true`, `priv_retention_purge` deletes those rows every day, and
`stg_ga4__events` stops loading anything older than the cutoff. Raw shards are dropped only with
`retention_include_raw_export = true` (or set a table expiration on the GA4 dataset).
GA4 itself keeps user level data in explorations for 2 or 14 months (property setting), the export
keeps everything forever unless you do something.

Careful: after the purge, a full refresh of the aggregated incremental reports starts at the
cutoff too. Do not full refresh `rpt_*` without need.

## suggested setup with the DPO

1. Week 1: everything off, read `priv_pii_summary`, `priv_consent_by_page`, `priv_data_inventory`.
   Fix the leaks in the tags (GA4 data redaction for web streams helps).
2. Decide retention (`data_retention_months`) and look at `priv_retention_preview`.
3. Load the DSR table, check `priv_dsr_deletion_preview` with a test request.
4. Turn on `enable_dsr_deletion`, then `enable_retention_purge`. Raw export flags last.
5. Give `ga4_privacy` access only to the DPO and data engineering.
