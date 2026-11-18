-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- did the launch work? the first 28 days of every new product (or collection)
-- fashion, toys, books, games, cosmetics, electronics: the launch week decides the season. A new
-- product is compared with the other launches at the SAME age, so a product of 5 days is not
-- compared with one of 5 months. Kill, push or reorder early.

WITH first_seen AS (
  SELECT item_id, ANY_VALUE(item_name) AS item_name, ANY_VALUE(item_category) AS item_category, MIN(event_date) AS launch_date
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 400 DAY) AND item_id IS NOT NULL
  GROUP BY item_id
  -- products that appeared after the first month of the window are launches
  HAVING MIN(event_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 370 DAY)
),
daily AS (
  SELECT f.item_id, DATE_DIFF(i.event_date, f.launch_date, DAY) AS age_days,
    COUNTIF(i.event_name = 'view_item') AS views,
    COUNTIF(i.event_name = 'add_to_cart') AS adds,
    COUNTIF(i.event_name = 'purchase') AS purchases,
    SUM(IF(i.event_name = 'purchase', i.item_revenue_fixed, 0)) AS revenue
  FROM first_seen AS f
  JOIN `your-gcp-project.ga4_core.fct_item_interactions` AS i USING (item_id)
  WHERE i.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 400 DAY)
    AND i.event_name IN ('view_item', 'add_to_cart', 'purchase')
  GROUP BY 1, 2
),
first_28 AS (
  SELECT
    f.item_id, f.item_name, f.item_category, f.launch_date,
    DATE_DIFF(CURRENT_DATE(), f.launch_date, DAY) AS age_today,
    SUM(IF(d.age_days < 7, d.views, 0)) AS views_week_1,
    SUM(IF(d.age_days < 28, d.views, 0)) AS views_28d,
    SUM(IF(d.age_days < 28, d.purchases, 0)) AS purchases_28d,
    SUM(IF(d.age_days < 28, d.revenue, 0)) AS revenue_28d,
    SAFE_DIVIDE(SUM(IF(d.age_days < 28, d.adds, 0)), SUM(IF(d.age_days < 28, d.views, 0))) AS add_rate_28d,
    -- growth of the views between week 1 and week 4 (word of mouth, or the push of the home ending?)
    SAFE_DIVIDE(SUM(IF(d.age_days BETWEEN 21 AND 27, d.views, 0)), NULLIF(SUM(IF(d.age_days < 7, d.views, 0)), 0)) AS week4_vs_week1
  FROM first_seen AS f
  LEFT JOIN daily AS d USING (item_id)
  GROUP BY 1, 2, 3, 4, 5
)
SELECT
  *,
  -- percentile against the launches of the same category that are already 28+ days old
  PERCENT_RANK() OVER (PARTITION BY item_category ORDER BY revenue_28d) AS revenue_percentile_in_category,
  CASE
    WHEN age_today < 28 THEN 'still_launching'
    WHEN PERCENT_RANK() OVER (PARTITION BY item_category ORDER BY revenue_28d) >= 0.8 THEN 'hit_reorder'
    WHEN week4_vs_week1 >= 1.2 THEN 'growing_push_it'
    WHEN views_28d >= 500 AND purchases_28d = 0 THEN 'attention_no_sales (price? photos?)'
    WHEN PERCENT_RANK() OVER (PARTITION BY item_category ORDER BY revenue_28d) <= 0.2 THEN 'flop'
    ELSE 'average'
  END AS launch_verdict
FROM first_28
ORDER BY launch_date DESC;

-- the life cycle after the launch (rising, peak, decline): ga4_ecommerce.ecom_item_momentum
