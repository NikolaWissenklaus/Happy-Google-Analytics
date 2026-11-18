-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- what are people asking for that the store does not deliver?
-- the site search is the only place where the customer TELLS you what they want, in their own
-- words. A term with many searches and no product view after it = missing product, missing
-- synonym or broken search. It is the purchase list for the buyers and the SEO briefing. Last 90 days.

WITH searches AS (
  SELECT
    e.session_key,
    e.event_ts,
    LOWER(TRIM(e.search_term)) AS term
  FROM `your-gcp-project.ga4_core.fct_events` AS e
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND e.event_name = 'view_search_results'
    AND e.search_term IS NOT NULL AND TRIM(e.search_term) != ''
),
after_search AS (
  SELECT
    s.session_key,
    s.term,
    s.event_ts,
    -- product view in the 10 minutes after the search
    COUNTIF(i.event_name = 'view_item' AND i.event_ts BETWEEN s.event_ts AND TIMESTAMP_ADD(s.event_ts, INTERVAL 10 MINUTE)) > 0 AS viewed_product,
    COUNTIF(i.event_name = 'add_to_cart' AND i.event_ts >= s.event_ts) > 0 AS added_to_cart
  FROM searches AS s
  LEFT JOIN `your-gcp-project.ga4_core.fct_item_interactions` AS i
    ON i.session_key = s.session_key
    AND i.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND i.event_name IN ('view_item', 'add_to_cart')
  GROUP BY 1, 2, 3
),
sessions AS (
  SELECT session_key, has_purchase, revenue
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
)
SELECT
  a.term,
  COUNT(*) AS searches,
  COUNT(DISTINCT a.session_key) AS sessions,
  SAFE_DIVIDE(COUNTIF(a.viewed_product), COUNT(*)) AS product_view_rate_after_search,
  SAFE_DIVIDE(COUNTIF(a.added_to_cart), COUNT(*)) AS add_rate_after_search,
  SAFE_DIVIDE(COUNT(DISTINCT IF(s.has_purchase, a.session_key, NULL)), COUNT(DISTINCT a.session_key)) AS session_conversion,
  CASE
    WHEN SAFE_DIVIDE(COUNTIF(a.viewed_product), COUNT(*)) < 0.2 THEN 'demand_not_met (no product / bad results)'
    WHEN SAFE_DIVIDE(COUNTIF(a.added_to_cart), COUNTIF(a.viewed_product)) < 0.05 THEN 'products_shown_do_not_fit (price, stock, relevance)'
    ELSE 'ok'
  END AS diagnosis
FROM after_search AS a
LEFT JOIN sessions AS s USING (session_key)
GROUP BY a.term
HAVING COUNT(*) >= 20
ORDER BY diagnosis != 'ok' DESC, searches DESC
LIMIT 200;

-- new terms of the last 14 days that did not exist before (trends, a competitor ad, a TikTok video)
WITH terms AS (
  SELECT LOWER(TRIM(search_term)) AS term, event_date
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 104 DAY)
    AND event_name = 'view_search_results' AND search_term IS NOT NULL
)
SELECT
  term,
  COUNTIF(event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)) AS searches_last_14d,
  COUNTIF(event_date < DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)) AS searches_previous_90d
FROM terms
GROUP BY term
HAVING searches_last_14d >= 15 AND searches_previous_90d <= 2
ORDER BY searches_last_14d DESC;

-- more on search: ga4_product.prod_search_content_gaps, prod_search_reformulations, ga4_data_science.ds_search_term_ngrams
