-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- BRAZIL: the WhatsApp button is a sales channel (and GA4 sees it as an outbound click)
-- half of the brazilian small and mid stores close sales on WhatsApp, and the GA4 revenue never
-- sees it. Here: every click to wa.me / api.whatsapp.com / web.whatsapp.com by page, channel and
-- hour, to measure the channel, staff the attendants and give the WhatsApp its share of credit.
-- Works with the enhanced measurement outbound clicks (event 'click' with link_url).

-- 1) WhatsApp clicks per day, and the share of sessions that clicked
SELECT
  e.event_date,
  COUNT(*) AS whatsapp_clicks,
  COUNT(DISTINCT e.session_key) AS sessions_clicking,
  SAFE_DIVIDE(COUNT(DISTINCT e.session_key), ANY_VALUE(d.sessions)) AS share_of_sessions
FROM `your-gcp-project.ga4_core.fct_events` AS e
JOIN (
  SELECT session_date, COUNT(*) AS sessions
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY 1
) AS d ON d.session_date = e.event_date
WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND REGEXP_CONTAINS(LOWER(COALESCE(e.link_url, '')), r'(wa\.me|api\.whatsapp\.com|web\.whatsapp\.com|whatsapp://)')
GROUP BY e.event_date
ORDER BY e.event_date;

-- 2) which pages and channels push people to WhatsApp (product pages = doubts the page does not
-- answer: size, freight, stock. Every repeated doubt is a missing line in the product page)
SELECT
  e.page_path,
  e.session_default_channel_group AS channel,
  COUNT(*) AS whatsapp_clicks,
  COUNT(DISTINCT e.session_key) AS sessions
FROM `your-gcp-project.ga4_core.fct_events` AS e
WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND REGEXP_CONTAINS(LOWER(COALESCE(e.link_url, '')), r'(wa\.me|api\.whatsapp\.com|web\.whatsapp\.com|whatsapp://)')
GROUP BY 1, 2
ORDER BY whatsapp_clicks DESC
LIMIT 100;

-- 3) attendant staffing: clicks per weekday x hour (local time)
SELECT
  EXTRACT(DAYOFWEEK FROM DATETIME(event_ts, 'America/Sao_Paulo')) AS weekday_sunday_1,
  EXTRACT(HOUR FROM DATETIME(event_ts, 'America/Sao_Paulo')) AS hour,
  COUNT(*) AS whatsapp_clicks
FROM `your-gcp-project.ga4_core.fct_events`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
  AND REGEXP_CONTAINS(LOWER(COALESCE(link_url, '')), r'(wa\.me|api\.whatsapp\.com|web\.whatsapp\.com|whatsapp://)')
GROUP BY 1, 2
ORDER BY 1, 2;

-- 4) does the WhatsApp click cannibalise or help the site sale? purchase on the site in the 7 days
-- after the click vs people that viewed the same product pages and did not click
WITH clickers AS (
  SELECT user_key, MIN(event_ts) AS click_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 67 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    AND REGEXP_CONTAINS(LOWER(COALESCE(link_url, '')), r'(wa\.me|api\.whatsapp\.com|web\.whatsapp\.com|whatsapp://)')
  GROUP BY user_key
)
SELECT
  COUNT(DISTINCT c.user_key) AS people_who_clicked,
  COUNT(DISTINCT t.user_key) AS bought_on_site_7d,
  SAFE_DIVIDE(COUNT(DISTINCT t.user_key), COUNT(DISTINCT c.user_key)) AS site_conversion_after_click
FROM clickers AS c
LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
  ON t.user_key = c.user_key
  AND t.is_valid_for_revenue
  AND t.transaction_ts BETWEEN c.click_ts AND TIMESTAMP_ADD(c.click_ts, INTERVAL 7 DAY);
-- the rest of the WhatsApp clickers probably bought IN the WhatsApp: ask the team how many sales
-- they closed and divide by the clicks, that is the conversion of the channel
