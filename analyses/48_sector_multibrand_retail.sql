-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: multi-brand retail, marketplaces, distributors, department stores
-- the brands are the suppliers AND the reason people come. The questions for the commercial
-- team: which brands sell, which ones only attract views, which ones are a door for new
-- customers, and how dependent the store is on a few of them (negotiation power).

-- 1) brand scorecard: views, view to purchase, revenue, share, new customer share (last 90 days)
WITH interactions AS (
  SELECT item_brand,
    COUNTIF(event_name = 'view_item') AS views,
    COUNTIF(event_name = 'add_to_cart') AS adds,
    COUNT(DISTINCT IF(event_name = 'view_item', item_id, NULL)) AS products_viewed
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND item_brand IS NOT NULL
  GROUP BY item_brand
),
sales AS (
  SELECT item_brand,
    SUM(item_revenue) AS revenue,
    SUM(quantity) AS units,
    COUNT(DISTINCT transaction_id) AS orders,
    COUNT(DISTINCT IF(is_first_purchase, transaction_id, NULL)) AS first_orders,
    AVG(price) AS avg_price,
    SUM(COALESCE(item_discount, 0) * COALESCE(quantity, 1)) AS discount_given
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND item_brand IS NOT NULL
  GROUP BY item_brand
)
SELECT
  i.item_brand,
  i.views,
  i.products_viewed,
  COALESCE(s.revenue, 0) AS revenue,
  SAFE_DIVIDE(s.revenue, SUM(s.revenue) OVER ()) AS share_of_revenue,
  SAFE_DIVIDE(i.views, SUM(i.views) OVER ()) AS share_of_views,
  SAFE_DIVIDE(s.units, i.views) AS units_per_view,
  SAFE_DIVIDE(i.adds, i.views) AS add_rate,
  SAFE_DIVIDE(s.first_orders, s.orders) AS share_orders_from_new_customers,
  s.avg_price,
  s.discount_given,
  -- share of revenue / share of views: below 0.6 = the brand attracts attention and does not sell
  SAFE_DIVIDE(SAFE_DIVIDE(s.revenue, SUM(s.revenue) OVER ()), SAFE_DIVIDE(i.views, SUM(i.views) OVER ())) AS sales_to_attention_ratio
FROM interactions AS i
LEFT JOIN sales AS s USING (item_brand)
WHERE i.views >= 200
ORDER BY revenue DESC;

-- 2) brand loyalty: of the customers that bought brand X, how many bought X again vs switched brand
-- inside the same category (high loyalty = a brand you cannot lose; low = a commodity)
WITH lines AS (
  SELECT user_key, transaction_ts, item_category, item_brand
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY)
    AND item_brand IS NOT NULL AND item_category IS NOT NULL
),
next_purchase AS (
  SELECT user_key, item_category, item_brand,
    LEAD(item_brand) OVER (PARTITION BY user_key, item_category ORDER BY transaction_ts) AS next_brand
  FROM lines
)
SELECT
  item_category,
  item_brand,
  COUNT(*) AS repeat_category_purchases,
  SAFE_DIVIDE(COUNTIF(next_brand = item_brand), COUNT(*)) AS brand_loyalty_rate,
  APPROX_TOP_COUNT(IF(next_brand != item_brand, next_brand, NULL), 3) AS switched_to
FROM next_purchase
WHERE next_brand IS NOT NULL
GROUP BY 1, 2
HAVING COUNT(*) >= 20
ORDER BY item_category, brand_loyalty_rate DESC;

-- 3) dependence on the top brands (HHI of the revenue by brand, per month)
SELECT month, SUM(share * share) AS brand_hhi, SAFE_DIVIDE(1, SUM(share * share)) AS effective_brands, MAX(share) AS top_brand_share
FROM (
  SELECT DATE_TRUNC(transaction_date, MONTH) AS month, item_brand,
    SAFE_DIVIDE(SUM(item_revenue), SUM(SUM(item_revenue)) OVER (PARTITION BY DATE_TRUNC(transaction_date, MONTH))) AS share
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
  GROUP BY 1, 2
)
GROUP BY month
ORDER BY month;
