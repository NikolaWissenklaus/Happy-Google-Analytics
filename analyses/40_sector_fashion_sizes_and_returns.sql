-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: fashion, shoes, sportswear (anything with sizes and colours)
-- in fashion the margin dies in two places: the size that is never in stock and the size that
-- comes back. Needs item_variant in the ecommerce events (size / colour).

-- 1) refund rate per product and variant: the size that does not fit (adjust the size chart,
-- write "veste pequeno" in the page, or stop buying that grade from the supplier)
WITH sold AS (
  SELECT item_id, ANY_VALUE(item_name) AS item_name, item_variant, SUM(quantity) AS units_sold
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue
    AND transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND item_variant IS NOT NULL
  GROUP BY item_id, item_variant
),
refunded AS (
  SELECT item_id, item_variant, SUM(COALESCE(quantity, 1)) AS units_refunded
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_name = 'refund' AND event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY 1, 2
)
SELECT
  s.item_id, s.item_name, s.item_variant, s.units_sold,
  COALESCE(r.units_refunded, 0) AS units_refunded,
  SAFE_DIVIDE(r.units_refunded, s.units_sold) AS refund_rate,
  -- refund rate of the variant / refund rate of the product: > 1.5 = this size is the problem
  SAFE_DIVIDE(SAFE_DIVIDE(r.units_refunded, s.units_sold),
    SAFE_DIVIDE(SUM(r.units_refunded) OVER (PARTITION BY s.item_id), SUM(s.units_sold) OVER (PARTITION BY s.item_id))) AS variant_vs_product
FROM sold AS s
LEFT JOIN refunded AS r USING (item_id, item_variant)
WHERE s.units_sold >= 10
ORDER BY variant_vs_product DESC
LIMIT 100;

-- 2) size curve of the demand (views) vs of the sales: the grade to buy next season
SELECT
  item_variant,
  COUNTIF(event_name = 'view_item') AS views,
  COUNTIF(event_name = 'add_to_cart') AS adds,
  COUNTIF(event_name = 'purchase') AS purchases,
  SAFE_DIVIDE(COUNTIF(event_name = 'view_item'), SUM(COUNTIF(event_name = 'view_item')) OVER ()) AS share_of_views,
  SAFE_DIVIDE(COUNTIF(event_name = 'purchase'), SUM(COUNTIF(event_name = 'purchase')) OVER ()) AS share_of_purchases
FROM `your-gcp-project.ga4_core.fct_item_interactions`
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND event_name IN ('view_item', 'add_to_cart', 'purchase')
  AND item_variant IS NOT NULL
GROUP BY item_variant
HAVING COUNTIF(event_name = 'view_item') >= 100
ORDER BY views DESC;

-- 3) the sizes people hunt and do not find (frontier): broken grades = lost sales
SELECT item_name, item_category, sessions_viewing, hunting_rate, add_rate_hunters, add_rate_non_hunters,
       estimated_revenue_lost, dead_end_variants, most_viewed_vs_most_bought
FROM `your-gcp-project.ga4_ecommerce.ecom_variant_hunting`
ORDER BY estimated_revenue_lost DESC
LIMIT 50;

-- 4) bracketing: orders with the SAME product in 2+ sizes (the customer buys two to return one)
SELECT
  DATE_TRUNC(transaction_date, MONTH) AS month,
  COUNT(DISTINCT transaction_id) AS orders_with_bracketing,
  SUM(item_revenue) AS revenue_in_those_lines
FROM (
  SELECT transaction_id, transaction_date, item_id, item_revenue,
    COUNT(DISTINCT item_variant) OVER (PARTITION BY transaction_id, item_id) AS variants_same_item
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
    AND item_variant IS NOT NULL
)
WHERE variants_same_item >= 2
GROUP BY month
ORDER BY month;

-- 5) collection sell-through (first 28 days of each new product): analyses/49_launches_and_collections.sql
