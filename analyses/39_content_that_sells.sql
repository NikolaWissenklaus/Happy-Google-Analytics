-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- does the blog / content sell anything?
-- content almost never gets the last click, so last click reports say "the blog is worthless".
-- Here: people who READ an article (engaged view of a blog page), and what they bought in the next
-- 30 days, against similar people who did not read. Last 120 days.

WITH readers AS (
  SELECT
    user_key,
    page_path,
    MIN(event_ts) AS first_read_ts
  FROM `your-gcp-project.ga4_core.fct_page_views`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
    AND page_type = 'blog'
    AND NOT is_bot_suspect
    -- a real read: 30s+ on the page or scrolled to 90%
    AND (time_on_page_sec >= 30 OR reached_90_percent)
  GROUP BY 1, 2
),
outcomes AS (
  SELECT
    r.page_path,
    r.user_key,
    COUNT(t.transaction_id) > 0 AS bought_30d,
    COALESCE(SUM(t.revenue), 0) AS revenue_30d
  FROM readers AS r
  LEFT JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = r.user_key
    AND t.is_valid_for_revenue
    AND t.transaction_ts > r.first_read_ts
    AND t.transaction_ts <= TIMESTAMP_ADD(r.first_read_ts, INTERVAL 30 DAY)
  GROUP BY 1, 2
)
-- 1) every article: readers, buyers in 30 days, influenced revenue
SELECT
  page_path,
  COUNT(*) AS readers,
  COUNTIF(bought_30d) AS buyers_30d,
  SAFE_DIVIDE(COUNTIF(bought_30d), COUNT(*)) AS reader_conversion_30d,
  SUM(revenue_30d) AS influenced_revenue_30d
FROM outcomes
GROUP BY page_path
HAVING COUNT(*) >= 50
ORDER BY influenced_revenue_30d DESC
LIMIT 100;

-- 2) readers vs non readers among people that visited the site in the same period
-- (an observational comparison: readers are more engaged people to start with, it is an upper bound)
WITH visitors AS (
  SELECT user_key, MIN(session_start_ts) AS first_ts, LOGICAL_OR(has_purchase) AS bought_in_window
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND NOT is_bot_suspect
    AND session_date < DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY user_key
),
read_any AS (
  SELECT DISTINCT user_key
  FROM `your-gcp-project.ga4_core.fct_page_views`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND page_type = 'blog'
    AND (time_on_page_sec >= 30 OR reached_90_percent)
)
SELECT
  r.user_key IS NOT NULL AS read_content,
  COUNT(*) AS people,
  SAFE_DIVIDE(COUNTIF(v.bought_in_window), COUNT(*)) AS purchase_rate
FROM visitors AS v
LEFT JOIN read_any AS r USING (user_key)
GROUP BY 1;

-- 3) the articles that send people to products (internal clicks to product pages)
SELECT
  page_path AS article,
  COUNT(*) AS views,
  COUNTIF(next_page_type = 'product') AS next_is_product,
  SAFE_DIVIDE(COUNTIF(next_page_type = 'product'), COUNT(*)) AS product_click_through
FROM (
  SELECT v.page_path,
    CASE WHEN REGEXP_CONTAINS(COALESCE(v.next_page_path, ''), r'(/p$|/p/|/produto/|/product/|/products/|-p-\d+|/dp/)') THEN 'product' ELSE 'other' END AS next_page_type
  FROM `your-gcp-project.ga4_core.fct_page_views` AS v
  WHERE v.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND v.page_type = 'blog'
)
GROUP BY page_path
HAVING COUNT(*) >= 100
ORDER BY product_click_through DESC
LIMIT 50;
