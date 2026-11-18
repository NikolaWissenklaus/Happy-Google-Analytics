-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- data engineering: will the GA4 export stop, and who eats the bytes (and the bill)?

-- 1) the headroom of the daily export (standard properties: 1 million events a day)
SELECT DISTINCT daily_event_limit, avg_events_last_7_days, max_events_in_a_day, headroom_share, days_over_limit,
       trend_events_per_day, projected_limit_date, days_to_limit, status
FROM `your-gcp-project.ga4_data_quality.dq_export_limit_headroom`;

-- 2) the events that fill the export, and the ones nobody asked for (candidates to drop or to sample)
SELECT event_name, events_per_day, event_share, cumulative_share, is_key_event, is_in_tracking_plan, is_automatic_event, is_drop_candidate
FROM `your-gcp-project.ga4_data_quality.dq_export_limit_headroom`
ORDER BY events_per_day DESC
LIMIT 40;

-- 3) the heaviest events in bytes (not in count) and what they add to the storage every month
SELECT event_name, events, bytes_per_event, share_of_export, estimated_gib_per_month, estimated_storage_usd_per_month
FROM `your-gcp-project.ga4_ops.ops_event_storage_footprint`
WHERE row_type = 'event'
ORDER BY logical_bytes DESC
LIMIT 20;

-- 4) the fat params: long strings in every event, unique values (cardinality bombs), outside the plan
SELECT event_name, param_key, rows_in_window, avg_string_length, distinct_values, share_of_export, estimated_gib_per_month, is_planned_param
FROM `your-gcp-project.ga4_ops.ops_event_storage_footprint`
WHERE row_type = 'param'
ORDER BY logical_bytes DESC
LIMIT 40;
