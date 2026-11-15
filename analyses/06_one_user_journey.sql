-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- what did this person do? (support ticket, bug report, "the customer says the coupon did not work")
-- user_key = 'uid:<user_id>' for logged users, 'dev:<user_pseudo_id>' for anonymous devices.
-- the anonymous sessions BEFORE the login are already stitched to the uid.

DECLARE who STRING DEFAULT 'uid:12345';

-- profile
SELECT *
FROM `your-gcp-project.ga4_segments.seg_user_profile_360`
WHERE user_key = who;

-- sessions, one by one
SELECT session_date, session_start_ts, session_default_channel_group, session_source_medium,
       landing_page_path, device_category, page_views, engagement_time_sec, key_events,
       transactions, revenue, is_bot_suspect, data_quality_score
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE user_key = who
ORDER BY session_start_ts DESC;

-- every event of the last session (staging keeps the details, PII already masked)
SELECT e.event_ts, e.event_name, e.page_path, e.page_title, e.transaction_id, e.coupon, e.event_value
FROM `your-gcp-project.ga4_staging.stg_ga4__events` AS e
JOIN `your-gcp-project.ga4_intermediate.int_ga4__user_stitching` AS s USING (user_pseudo_id)
WHERE s.user_key = who
  AND e.event_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 7 DAY)
ORDER BY e.event_ts DESC
LIMIT 300;
