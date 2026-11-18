-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: lead generation (B2B, education, real estate, cars, insurance, health, services, SaaS)
-- the site does not sell, it generates contacts. The questions: which channel and page bring
-- leads, at what time the sales team must be online, how long people take to decide to talk,
-- and which leads are worth more (they came back, they saw the price page...).
-- Put the event names of your leads below.

DECLARE lead_events ARRAY<STRING> DEFAULT ['generate_lead', 'form_submit', 'sign_up', 'contact', 'request_quote', 'schedule'];

-- 1) leads per channel and landing page, with the lead rate (last 90 days)
SELECT
  s.session_default_channel_group AS channel,
  s.landing_page_path,
  COUNT(*) AS sessions,
  COUNT(DISTINCT k.session_key) AS sessions_with_lead,
  SAFE_DIVIDE(COUNT(DISTINCT k.session_key), COUNT(*)) AS lead_rate
FROM `your-gcp-project.ga4_core.fct_sessions` AS s
LEFT JOIN `your-gcp-project.ga4_core.fct_key_events` AS k
  ON k.session_key = s.session_key
  AND k.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND (k.key_event_name IN UNNEST(lead_events) OR k.event_name IN UNNEST(lead_events))
WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND NOT s.is_bot_suspect
GROUP BY 1, 2
HAVING COUNT(*) >= 100
ORDER BY sessions_with_lead DESC
LIMIT 100;

-- 2) when the leads arrive (weekday x hour): the shift of the sales / SDR team.
-- a lead answered in 5 minutes converts many times more than one answered tomorrow
SELECT
  EXTRACT(DAYOFWEEK FROM DATETIME(event_ts, 'America/Sao_Paulo')) AS weekday_sunday_1,
  EXTRACT(HOUR FROM DATETIME(event_ts, 'America/Sao_Paulo')) AS hour,
  COUNT(*) AS leads,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) AS share_of_leads
FROM `your-gcp-project.ga4_core.fct_key_events`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND (key_event_name IN UNNEST(lead_events) OR event_name IN UNNEST(lead_events))
  AND NOT is_bot_suspect
GROUP BY 1, 2
ORDER BY 1, 2;

-- 3) how long people take to raise the hand: sessions and days from the first visit to the lead,
-- per channel of the FIRST visit (the channel that starts the conversation)
WITH leads AS (
  SELECT user_key, MIN(event_ts) AS lead_ts
  FROM `your-gcp-project.ga4_core.fct_key_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND (key_event_name IN UNNEST(lead_events) OR event_name IN UNNEST(lead_events))
  GROUP BY user_key
)
SELECT
  ARRAY_AGG(s.session_default_channel_group ORDER BY s.session_start_ts LIMIT 1)[OFFSET(0)] AS first_channel,
  l.user_key,
  COUNT(*) AS sessions_until_lead,
  TIMESTAMP_DIFF(l.lead_ts, MIN(s.session_start_ts), HOUR) / 24 AS days_until_lead
FROM leads AS l
JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
  ON s.user_key = l.user_key
  AND s.session_start_ts <= l.lead_ts
  AND s.session_start_ts >= TIMESTAMP_SUB(l.lead_ts, INTERVAL 90 DAY)
WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
GROUP BY l.user_key, l.lead_ts
LIMIT 1000;

-- 4) lead scoring by behaviour BEFORE the form (pages seen in the session of the lead).
-- leads that saw the price / plans page or came back 3+ times are the hot ones for sales
SELECT
  k.user_key,
  k.event_ts AS lead_ts,
  k.session_default_channel_group AS channel,
  s.session_number,
  s.page_views,
  s.engagement_time_sec,
  LOGICAL_OR(REGEXP_CONTAINS(v.page_path, r'(preco|precos|price|pricing|planos|plans|orcamento|valores)')) AS saw_pricing,
  LOGICAL_OR(REGEXP_CONTAINS(v.page_path, r'(case|cases|clientes|depoimentos|portfolio)')) AS saw_cases,
  (IF(s.session_number >= 3, 30, 0)
    + IF(LOGICAL_OR(REGEXP_CONTAINS(v.page_path, r'(preco|precos|price|pricing|planos|plans|orcamento|valores)')), 40, 0)
    + IF(s.engagement_time_sec >= 120, 20, 0)
    + IF(LOGICAL_OR(REGEXP_CONTAINS(v.page_path, r'(case|cases|clientes|depoimentos|portfolio)')), 10, 0)) AS lead_score
FROM `your-gcp-project.ga4_core.fct_key_events` AS k
JOIN `your-gcp-project.ga4_core.fct_sessions` AS s USING (session_key)
LEFT JOIN `your-gcp-project.ga4_core.fct_page_views` AS v
  ON v.session_key = k.session_key AND v.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 15 DAY)
WHERE k.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
  AND (k.key_event_name IN UNNEST(lead_events) OR k.event_name IN UNNEST(lead_events))
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY lead_score DESC, lead_ts DESC;

-- with enable_crm the lead to customer funnel by channel is in ga4_crm.crm_lead_to_customer
