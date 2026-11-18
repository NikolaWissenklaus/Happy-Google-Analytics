-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- does the assortment sit where the demand is?
-- per category, the price band of what people LOOK at, of what they BUY and of what the store
-- OFFERS (distinct products seen in the window). A band with demand and few products is a gap
-- in the assortment; a band with many products and no sales is dead stock. Last 90 days.

WITH views AS (
  SELECT item_category, item_id, price
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND event_name = 'view_item' AND price > 0
),
quartiles AS (
  -- bands by the quartiles of the viewed prices of each category (comparable across categories)
  SELECT item_category, APPROX_QUANTILES(price, 4) AS q
  FROM views
  GROUP BY item_category
),
banded_views AS (
  SELECT v.item_category, v.item_id,
    CASE WHEN v.price <= q.q[OFFSET(1)] THEN '1_entry' WHEN v.price <= q.q[OFFSET(2)] THEN '2_mid_low'
         WHEN v.price <= q.q[OFFSET(3)] THEN '3_mid_high' ELSE '4_premium' END AS band
  FROM views AS v JOIN quartiles AS q USING (item_category)
),
banded_sales AS (
  SELECT t.item_category,
    CASE WHEN t.price <= q.q[OFFSET(1)] THEN '1_entry' WHEN t.price <= q.q[OFFSET(2)] THEN '2_mid_low'
         WHEN t.price <= q.q[OFFSET(3)] THEN '3_mid_high' ELSE '4_premium' END AS band,
    t.quantity, t.item_revenue
  FROM `your-gcp-project.ga4_core.fct_transaction_items` AS t
  JOIN quartiles AS q USING (item_category)
  WHERE t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND t.is_valid_for_revenue AND t.price > 0
),
v AS (
  SELECT item_category, band, COUNT(*) AS views, COUNT(DISTINCT item_id) AS products_offered
  FROM banded_views GROUP BY 1, 2
),
s AS (
  SELECT item_category, band, SUM(quantity) AS units, SUM(item_revenue) AS revenue
  FROM banded_sales GROUP BY 1, 2
)
SELECT
  v.item_category,
  v.band,
  q.q AS price_quartiles,
  v.views,
  v.products_offered,
  COALESCE(s.units, 0) AS units,
  COALESCE(s.revenue, 0) AS revenue,
  SAFE_DIVIDE(v.views, SUM(v.views) OVER (PARTITION BY v.item_category)) AS share_of_demand,
  SAFE_DIVIDE(v.products_offered, SUM(v.products_offered) OVER (PARTITION BY v.item_category)) AS share_of_assortment,
  SAFE_DIVIDE(s.revenue, SUM(s.revenue) OVER (PARTITION BY v.item_category)) AS share_of_revenue,
  SAFE_DIVIDE(s.units, v.views) AS units_per_view,
  -- demand / assortment > 1.5 = too few products for the interest (buy more of this band)
  SAFE_DIVIDE(
    SAFE_DIVIDE(v.views, SUM(v.views) OVER (PARTITION BY v.item_category)),
    SAFE_DIVIDE(v.products_offered, SUM(v.products_offered) OVER (PARTITION BY v.item_category))
  ) AS demand_to_assortment_ratio
FROM v
LEFT JOIN s USING (item_category, band)
JOIN quartiles AS q ON q.item_category = v.item_category
ORDER BY v.item_category, v.band;

-- price elasticity and the psychology of the price endings already have their own models:
-- ga4_ecommerce.ecom_price_elasticity, ecom_price_ending_psychology, ecom_price_anchoring (frontier)
