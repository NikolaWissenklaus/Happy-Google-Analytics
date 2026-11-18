-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the 80/20 of the catalogue: how many products make 80% of the revenue, which ones are dead
-- (people look and nobody buys) and which ones are invisible (nobody even sees them).
-- Stock, photos, ads and SEO effort should follow this list. Last 90 days.

-- 1) pareto curve: cumulative share of revenue by product rank
WITH item_revenue AS (
  SELECT item_id, ANY_VALUE(item_name) AS item_name, ANY_VALUE(item_category) AS item_category,
         SUM(item_revenue) AS revenue, SUM(quantity) AS units
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND is_valid_for_revenue
  GROUP BY item_id
),
ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (ORDER BY revenue DESC) AS revenue_rank,
    COUNT(*) OVER () AS items_selling,
    SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / SUM(revenue) OVER () AS cumulative_share
  FROM item_revenue
)
SELECT
  COUNTIF(cumulative_share <= 0.5) AS items_for_50pct_revenue,
  COUNTIF(cumulative_share <= 0.8) AS items_for_80pct_revenue,
  COUNTIF(cumulative_share <= 0.95) AS items_for_95pct_revenue,
  ANY_VALUE(items_selling) AS items_with_sales,
  SAFE_DIVIDE(COUNTIF(cumulative_share <= 0.8), ANY_VALUE(items_selling)) AS share_of_items_for_80pct
FROM ranked;

-- 2) every product classified: star / steady / dead (views and no sales) / invisible (no views)
WITH views AS (
  SELECT item_id, ANY_VALUE(item_name) AS item_name, ANY_VALUE(item_category) AS item_category,
         COUNTIF(event_name = 'view_item') AS views,
         COUNTIF(event_name = 'add_to_cart') AS adds,
         COUNTIF(event_name = 'view_item_list') AS list_impressions
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND item_id IS NOT NULL
  GROUP BY item_id
),
sales AS (
  SELECT item_id, SUM(item_revenue) AS revenue, SUM(quantity) AS units
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND is_valid_for_revenue
  GROUP BY item_id
),
joined AS (
  SELECT v.*, COALESCE(s.revenue, 0) AS revenue, COALESCE(s.units, 0) AS units,
    SAFE_DIVIDE(s.units, v.views) AS units_per_view,
    PERCENT_RANK() OVER (ORDER BY COALESCE(s.revenue, 0)) AS revenue_percentile,
    PERCENT_RANK() OVER (ORDER BY v.views) AS views_percentile
  FROM views AS v
  LEFT JOIN sales AS s USING (item_id)
)
SELECT
  *,
  CASE
    WHEN revenue_percentile >= 0.9 THEN 'star'
    WHEN views >= 200 AND units = 0 THEN 'dead_seen_not_bought'
    WHEN views < 20 AND list_impressions < 200 THEN 'invisible'
    WHEN views_percentile < 0.3 AND units_per_view > 0.03 THEN 'hidden_gem_needs_traffic'
    ELSE 'steady'
  END AS catalogue_role
FROM joined
ORDER BY revenue DESC;

-- 3) concentration per category: a category where 3 products are 80% of the revenue depends on
-- their stock; one where it takes 300 depends on search and navigation
WITH item_revenue AS (
  SELECT item_category, item_id, SUM(item_revenue) AS revenue
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND is_valid_for_revenue
  GROUP BY 1, 2
),
shares AS (
  SELECT *, SAFE_DIVIDE(revenue, SUM(revenue) OVER (PARTITION BY item_category)) AS share,
    SUM(revenue) OVER (PARTITION BY item_category ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
      / SUM(revenue) OVER (PARTITION BY item_category) AS cumulative_share
  FROM item_revenue
)
SELECT
  item_category,
  SUM(revenue) AS revenue,
  COUNT(*) AS items_with_sales,
  COUNTIF(cumulative_share <= 0.8) + 1 AS items_for_80pct,
  SUM(share * share) AS hhi,
  MAX(share) AS top_item_share
FROM shares
GROUP BY item_category
ORDER BY revenue DESC;
