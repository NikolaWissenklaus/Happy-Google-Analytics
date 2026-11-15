-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- UTM problems to send to the agency / CRM team, with the suggested fix and how many sessions
-- each one is throwing into the wrong channel (or into Unassigned)

SELECT
  severity,
  issue,
  raw_source,
  raw_medium,
  raw_campaign,
  suggestion,
  sessions_affected,
  first_seen,
  last_seen
FROM `your-gcp-project.ga4_marketing.mkt_utm_linter`
WHERE last_seen >= DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 30 DAY)
ORDER BY sessions_affected DESC
LIMIT 100;

-- why is there (not set) / Unassigned at all
SELECT *
FROM `your-gcp-project.ga4_data_quality.dq_not_set_diagnostics`
LIMIT 50;
