-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- ANY BUSINESS: what in the FIRST visit tells who will be valuable?
-- before BQML (ds_scores_* when enable_bqml is on) there is a lot of value in a plain lift table:
-- for each characteristic of the first session, the share of people that bought in 90 days and the
-- revenue per person, against the average. Good to choose audiences for media on day 1, to know
-- which first experience matters, and to explain the model to the business later.

-- 1) lift table: every feature of the first session vs buying in 90 days
WITH first_sessions AS (
  SELECT
    s.user_key,
    s.session_date,
    s.session_default_channel_group,
    s.device_category,
    s.landing_page_type,
    s.geo_macro_region,
    CASE WHEN s.session_hour < 6 THEN '00-05' WHEN s.session_hour < 12 THEN '06-11' WHEN s.session_hour < 18 THEN '12-17' ELSE '18-23' END AS day_part,
    IF(s.is_engaged, 'engaged', 'not engaged') AS engaged,
    CASE WHEN s.page_views <= 1 THEN '1 page' WHEN s.page_views <= 3 THEN '2-3 pages' WHEN s.page_views <= 7 THEN '4-7 pages' ELSE '8+ pages' END AS depth,
    IF(s.has_site_search, 'searched', 'no search') AS searched,
    IF(s.has_add_to_cart, 'added to cart', 'no cart') AS cart,
    IF(s.has_purchase, 'bought in the 1st visit', 'did not buy in the 1st visit') AS bought_first
  FROM `your-gcp-project.ga4_core.fct_sessions` AS s
  WHERE s.session_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 270 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND s.is_new_user
    AND NOT s.is_bot_suspect
),
value_90d AS (
  SELECT f.user_key, SUM(t.revenue) AS revenue_90d, COUNT(t.transaction_id) AS orders_90d
  FROM first_sessions AS f
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key
    AND t.transaction_date BETWEEN f.session_date AND DATE_ADD(f.session_date, INTERVAL 89 DAY)
  WHERE t.is_valid_for_revenue
    AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 270 DAY)
  GROUP BY 1
),
joined AS (
  SELECT f.*, COALESCE(v.revenue_90d, 0) AS revenue_90d, COALESCE(v.orders_90d, 0) > 0 AS bought_90d
  FROM first_sessions AS f
  LEFT JOIN value_90d AS v USING (user_key)
),
long_format AS (
  SELECT feature, value, bought_90d, revenue_90d
  FROM joined,
  UNNEST([
    STRUCT('channel' AS feature, session_default_channel_group AS value),
    ('device', device_category),
    ('landing type', landing_page_type),
    ('region', geo_macro_region),
    ('day part', day_part),
    ('engaged', engaged),
    ('depth', depth),
    ('search', searched),
    ('cart', cart),
    ('bought first', bought_first)
  ])
),
overall AS (
  SELECT AVG(IF(bought_90d, 1, 0)) AS buy_rate, AVG(revenue_90d) AS revenue_per_user FROM joined
)
SELECT
  l.feature,
  COALESCE(l.value, '(not set)') AS value,
  COUNT(*) AS new_users,
  AVG(IF(l.bought_90d, 1, 0)) AS buy_rate_90d,
  AVG(l.revenue_90d) AS revenue_per_user_90d,
  SAFE_DIVIDE(AVG(IF(l.bought_90d, 1, 0)), ANY_VALUE(o.buy_rate)) AS buy_rate_lift,
  SAFE_DIVIDE(AVG(l.revenue_90d), ANY_VALUE(o.revenue_per_user)) AS value_lift
FROM long_format AS l
CROSS JOIN overall AS o
GROUP BY 1, 2
HAVING COUNT(*) >= 200
ORDER BY feature, value_lift DESC;

-- 2) a points score from the lifts above (log of the lift, like a naive bayes), and how well it sorts people
-- run 1) first and adjust the features; this one rebuilds the same tables to stay self contained
WITH first_sessions AS (
  SELECT
    s.user_key, s.session_date,
    s.session_default_channel_group AS channel,
    s.device_category AS device,
    IF(s.is_engaged, 'y', 'n') AS engaged,
    IF(s.has_add_to_cart, 'y', 'n') AS cart,
    IF(s.has_site_search, 'y', 'n') AS searched
  FROM `your-gcp-project.ga4_core.fct_sessions` AS s
  WHERE s.session_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 270 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND s.is_new_user AND NOT s.is_bot_suspect
),
buyers_90d AS (
  SELECT DISTINCT f.user_key
  FROM first_sessions AS f
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key
    AND t.transaction_date BETWEEN f.session_date AND DATE_ADD(f.session_date, INTERVAL 89 DAY)
  WHERE t.is_valid_for_revenue
    AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 270 DAY)
),
labels AS (
  SELECT f.*, b.user_key IS NOT NULL AS bought
  FROM first_sessions AS f
  LEFT JOIN buyers_90d AS b USING (user_key)
),
base AS (SELECT AVG(IF(bought, 1, 0)) AS p FROM labels),
lift_channel AS (SELECT channel, LN(SAFE_DIVIDE(AVG(IF(bought, 1, 0)) + 0.001, ANY_VALUE(b.p))) AS pts FROM labels CROSS JOIN base AS b GROUP BY 1),
lift_device AS (SELECT device, LN(SAFE_DIVIDE(AVG(IF(bought, 1, 0)) + 0.001, ANY_VALUE(b.p))) AS pts FROM labels CROSS JOIN base AS b GROUP BY 1),
lift_engaged AS (SELECT engaged, LN(SAFE_DIVIDE(AVG(IF(bought, 1, 0)) + 0.001, ANY_VALUE(b.p))) AS pts FROM labels CROSS JOIN base AS b GROUP BY 1),
lift_cart AS (SELECT cart, LN(SAFE_DIVIDE(AVG(IF(bought, 1, 0)) + 0.001, ANY_VALUE(b.p))) AS pts FROM labels CROSS JOIN base AS b GROUP BY 1),
lift_search AS (SELECT searched, LN(SAFE_DIVIDE(AVG(IF(bought, 1, 0)) + 0.001, ANY_VALUE(b.p))) AS pts FROM labels CROSS JOIN base AS b GROUP BY 1),
scored AS (
  SELECT l.bought, COALESCE(c.pts, 0) + COALESCE(d.pts, 0) + COALESCE(e.pts, 0) + COALESCE(k.pts, 0) + COALESCE(s.pts, 0) AS score
  FROM labels AS l
  LEFT JOIN lift_channel AS c USING (channel)
  LEFT JOIN lift_device AS d USING (device)
  LEFT JOIN lift_engaged AS e USING (engaged)
  LEFT JOIN lift_cart AS k USING (cart)
  LEFT JOIN lift_search AS s USING (searched)
)
SELECT
  decile,
  COUNT(*) AS users,
  AVG(IF(bought, 1, 0)) AS buy_rate,
  SAFE_DIVIDE(SUM(IF(bought, 1, 0)), SUM(SUM(IF(bought, 1, 0))) OVER ()) AS share_of_buyers
FROM (SELECT *, NTILE(10) OVER (ORDER BY score DESC) AS decile FROM scored)
GROUP BY 1
ORDER BY 1;
-- decile 1 with 40% of the buyers = a day 1 audience for remarketing that is 4x better than random.
-- (in sample, so it is optimistic. For production use ds_scores_purchase_propensity)
