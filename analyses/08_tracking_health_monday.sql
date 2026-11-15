-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- monday morning checklist of the analytics team

-- what changed in the GA4 data this week (export schema, events, params, hostnames, streams...)
SELECT change_date, severity, change_type, subject, details
FROM `your-gcp-project.ga4_watch.watch_tracking_changelog`
WHERE change_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 7 DAY)
ORDER BY severity = 'critical' DESC, severity = 'warning' DESC, change_date DESC;

-- tracking plan: what is broken today (required params missing, wrong types, events without items)
SELECT violation_type, event_name, param_name, SUM(events_affected) AS events_affected, MAX(share_affected) AS worst_share, ANY_VALUE(severity) AS severity
FROM `your-gcp-project.ga4_governance.gov_tracking_plan_violations`
WHERE event_date >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 7 DAY)
GROUP BY 1, 2, 3
ORDER BY severity = 'high' DESC, events_affected DESC;

-- planned events that are missing or half implemented
SELECT DISTINCT event_name, owner, event_status
FROM `your-gcp-project.ga4_governance.gov_tracking_plan_coverage`
WHERE event_status != 'implemented'
ORDER BY event_status;

-- PII leaking into GA4 (send to the dev team with the masked example)
SELECT field, pii_kind, status, occurrences_last_7d, latest_masked_example, how_to_fix
FROM `your-gcp-project.ga4_privacy.priv_pii_summary`
WHERE status != 'fixed'
ORDER BY occurrences_last_7d DESC;
