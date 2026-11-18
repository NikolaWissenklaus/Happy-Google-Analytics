-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- not every session is a failed purchase. prod_session_intent_taxonomy tells what the visit was for
-- (Broder's navigational / informational / transactional, plus cart building, research, service...)

-- 1) the intent mix of the last 28 days, and what each intent is worth now and later
SELECT
  intent,
  intent_family,
  SUM(sessions) AS sessions,
  SUM(sessions) / SUM(SUM(sessions)) OVER () AS share,
  SAFE_DIVIDE(SUM(transactions), SUM(sessions)) AS conversion_rate,
  SAFE_DIVIDE(SUM(sessions_bought_later), SUM(sessions - sessions_with_purchase)) AS bought_in_the_next_days
FROM `your-gcp-project.ga4_product.prod_session_intent_taxonomy`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
GROUP BY 1, 2
ORDER BY sessions DESC;

-- 2) what each channel brings: a channel full of 'bounce' and 'home_and_navigation' is not a demand channel
SELECT
  session_default_channel_group,
  intent,
  SUM(sessions) AS sessions,
  SUM(sessions) / SUM(SUM(sessions)) OVER (PARTITION BY session_default_channel_group) AS share_of_channel
FROM `your-gcp-project.ga4_product.prod_session_intent_taxonomy`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
GROUP BY 1, 2
QUALIFY SUM(SUM(sessions)) OVER (PARTITION BY session_default_channel_group) >= 1000
ORDER BY 1, sessions DESC;

-- 3) research is an investment: comparison sessions that bought later, by device (remarketing window!)
SELECT device_category, SUM(sessions) AS research_sessions,
  SAFE_DIVIDE(SUM(sessions_bought_later), SUM(sessions - sessions_with_purchase)) AS bought_later_rate
FROM `your-gcp-project.ga4_product.prod_session_intent_taxonomy`
WHERE intent = 'comparison_research'
  AND session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
GROUP BY 1
ORDER BY 2 DESC;

-- 4) post purchase service visits growing = a logistics or product problem before the reviews show it
SELECT DATE_TRUNC(session_date, WEEK(MONDAY)) AS week, SUM(sessions) AS service_sessions,
  SUM(sessions) / ANY_VALUE(week_sessions) AS share_of_all_sessions
FROM (
  SELECT *, SUM(sessions) OVER (PARTITION BY DATE_TRUNC(session_date, WEEK(MONDAY))) AS week_sessions
  FROM `your-gcp-project.ga4_product.prod_session_intent_taxonomy`
)
WHERE intent = 'post_purchase_service'
GROUP BY 1
ORDER BY 1;
