-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- how to sell more per order (and not only more orders)?
-- the cheapest growth is the second item in the same box: no new CAC, often no new freight.
-- Last 180 days.

-- 1) items per order and the AOV of each basket size: how much a single item order costs you
SELECT
  LEAST(item_quantity, 6) AS items_in_order,
  COUNT(*) AS orders,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) AS share_of_orders,
  AVG(revenue) AS aov,
  AVG(shipping_value) AS avg_shipping
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
GROUP BY 1
ORDER BY 1;

-- 2) single item orders per category: where the cross-sell block is missing
WITH orders AS (
  SELECT transaction_id, COUNT(*) AS lines, ANY_VALUE(item_category) AS category_if_single
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  GROUP BY transaction_id
),
category_orders AS (
  SELECT DISTINCT i.transaction_id, i.item_category, o.lines
  FROM `your-gcp-project.ga4_core.fct_transaction_items` AS i
  JOIN orders AS o USING (transaction_id)
  WHERE i.is_valid_for_revenue AND i.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
)
SELECT
  item_category,
  COUNT(*) AS orders_with_category,
  SAFE_DIVIDE(COUNTIF(lines = 1), COUNT(*)) AS single_item_share,
  AVG(lines) AS avg_lines_when_category_present
FROM category_orders
GROUP BY item_category
HAVING COUNT(*) >= 50
ORDER BY single_item_share DESC;

-- 3) attach rate between categories: of the orders with category A, how many also had B
-- (lift > 1 = they go together more than by chance, put B next to A)
WITH oc AS (
  SELECT DISTINCT transaction_id, item_category
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
    AND item_category IS NOT NULL
),
totals AS (SELECT COUNT(DISTINCT transaction_id) AS orders FROM oc),
cat AS (SELECT item_category, COUNT(*) AS orders FROM oc GROUP BY 1)
SELECT
  a.item_category AS category_a,
  b.item_category AS category_b,
  COUNT(*) AS orders_together,
  SAFE_DIVIDE(COUNT(*), ANY_VALUE(ca.orders)) AS attach_rate_b_given_a,
  SAFE_DIVIDE(SAFE_DIVIDE(COUNT(*), ANY_VALUE(ca.orders)), SAFE_DIVIDE(ANY_VALUE(cb.orders), ANY_VALUE(t.orders))) AS lift
FROM oc AS a
JOIN oc AS b ON b.transaction_id = a.transaction_id AND b.item_category != a.item_category
JOIN cat AS ca ON ca.item_category = a.item_category
JOIN cat AS cb ON cb.item_category = b.item_category
CROSS JOIN totals AS t
GROUP BY 1, 2
HAVING COUNT(*) >= 20
ORDER BY lift DESC
LIMIT 100;

-- item level rules and recommendations: ga4_ecommerce.ecom_market_basket_rules, ecom_item_recommendations
