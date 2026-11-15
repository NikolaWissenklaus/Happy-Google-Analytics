// author: Francisco Lucas / Nikola Wissenklaus / Chico

// LGPD assertions. These are the ones that matter most: when one fails, stop the activation
// syncs until it is fixed.

function check(name, description, query) {
  assert(name, {
    description,
    tags: ["assertions", "daily", "lgpd"]
  }).query(query);
}

check("assert_activation_only_consented_users",
  "No activation table can have a user without the permission of its destination (priv_activation_consent_audit)",
  ctx => `
SELECT activation_table, permission_needed, rows_not_allowed
FROM ${ctx.ref("priv_activation_consent_audit")}
WHERE rows_not_allowed > 0`);

if (constants.MASK_PII) {
  check("assert_no_clear_pii_in_staging",
    "With mask_pii_in_urls = true, no e-mail or formatted CPF can be left in page_location / page_referrer / page_title of staging (last 3 days)",
    ctx => `
SELECT event_date, event_name, COUNT(*) AS events
FROM ${ctx.ref("stg_ga4__events")}
WHERE event_date >= DATE_SUB(CURRENT_DATE('${constants.TIMEZONE}'), INTERVAL 3 DAY)
  AND (
    REGEXP_CONTAINS(CONCAT(COALESCE(page_location, ''), ' ', COALESCE(page_referrer, ''), ' ', COALESCE(page_title, '')), r'${privacy.PATTERNS.email}')
    OR REGEXP_CONTAINS(CONCAT(COALESCE(page_location, ''), ' ', COALESCE(page_referrer, ''), ' ', COALESCE(page_title, '')), r'${privacy.PATTERNS.cpf_formatted}')
  )
GROUP BY 1, 2`);
}

check("assert_user_id_is_not_pii_after_staging",
  "user_id in staging must never be an e-mail in clear text (staging hashes it when mask_pii_in_urls = true)",
  ctx => `
SELECT event_date, COUNT(*) AS events
FROM ${ctx.ref("stg_ga4__events")}
WHERE event_date >= DATE_SUB(CURRENT_DATE('${constants.TIMEZONE}'), INTERVAL 3 DAY)
  AND REGEXP_CONTAINS(user_id, r'${privacy.PATTERNS.email}')
  AND ${constants.MASK_PII ? "TRUE" : "FALSE"}
GROUP BY 1`);

check("assert_dsr_requests_within_sla",
  "Data subject requests open beyond the legal deadline (cfg_privacy.dsr_sla_days, LGPD art. 19)",
  ctx => `
SELECT request_id, request_type, requested_at, due_date, pipeline_status
FROM ${ctx.ref("priv_dsr_requests")}
WHERE is_overdue`);

check("assert_deleted_people_stay_deleted",
  "Nobody of the suppression list can be in staging again (a full refresh without the filter would bring them back)",
  ctx => `
SELECT s.event_date, COUNT(*) AS events
FROM ${ctx.ref("stg_ga4__events")} AS s
JOIN ${ctx.ref("priv_dsr_suppression_list")} AS l
  ON l.id_type = 'user_pseudo_id' AND l.value_sha256 = TO_HEX(SHA256(s.user_pseudo_id))
WHERE s.event_date >= DATE_SUB(CURRENT_DATE('${constants.TIMEZONE}'), INTERVAL 7 DAY)
GROUP BY 1`);
