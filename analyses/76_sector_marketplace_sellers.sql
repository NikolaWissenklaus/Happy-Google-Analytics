-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: marketplaces, multi seller stores, franchises, dropshipping (the seller is in `affiliation`)
-- the store does not own the experience: each seller ships, prices and answers on its own. The
-- questions: which sellers bring money and which bring refunds, how concentrated the GMV is, which
-- sellers lose the buy box (people view and buy from another), and which ones repeat customers.
-- Needs the `affiliation` of the items (GA4 recommended item param). Change to item_brand or an
-- item param if your sellers come in another field.

-- 1) seller scorecard: GMV, orders, customers, refund rate, repeat customers, AOV (last 90 days)
WITH lines AS (
  SELECT
    COALESCE(affiliation, '(not set)') AS seller,
    transaction_id,
    user_key,
    item_revenue,
    is_first_purchase
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND is_valid_for_revenue
),
refunds AS (
  SELECT transaction_id, refunded_value, revenue
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
),
per_seller AS (
  SELECT
    l.seller,
    SUM(l.item_revenue) AS gmv,
    COUNT(DISTINCT l.transaction_id) AS orders,
    COUNT(DISTINCT l.user_key) AS customers,
    -- refund of the order split by the share of the seller in the order
    SUM(SAFE_DIVIDE(l.item_revenue, r.revenue) * COALESCE(r.refunded_value, 0)) AS refunded_estimate
  FROM lines AS l
  LEFT JOIN refunds AS r USING (transaction_id)
  GROUP BY 1
),
repeat_customers AS (
  SELECT seller, COUNT(*) AS repeat_customers
  FROM (SELECT seller, user_key FROM lines GROUP BY 1, 2 HAVING COUNT(DISTINCT transaction_id) >= 2)
  GROUP BY 1
)
SELECT
  p.*,
  COALESCE(rc.repeat_customers, 0) AS repeat_customers,
  SAFE_DIVIDE(p.gmv, p.orders) AS avg_seller_ticket,
  SAFE_DIVIDE(p.refunded_estimate, p.gmv) AS refund_rate,
  SAFE_DIVIDE(COALESCE(rc.repeat_customers, 0), p.customers) AS repeat_rate,
  SAFE_DIVIDE(p.gmv, SUM(p.gmv) OVER ()) AS gmv_share,
  SUM(p.gmv) OVER (ORDER BY p.gmv DESC) / SUM(p.gmv) OVER () AS cumulative_gmv_share
FROM per_seller AS p
LEFT JOIN repeat_customers AS rc USING (seller)
ORDER BY gmv DESC;
-- cumulative_gmv_share hits 80% at seller N: that is the size of the "key accounts" team you need

-- 2) seller concentration over time (Herfindahl index of GMV per month). Going up = dependency
WITH m AS (
  SELECT DATE_TRUNC(transaction_date, MONTH) AS month_start, COALESCE(affiliation, '(not set)') AS seller, SUM(item_revenue) AS gmv
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 18 MONTH)
    AND is_valid_for_revenue
  GROUP BY 1, 2
)
SELECT
  month_start,
  COUNT(*) AS active_sellers,
  SUM(POW(SAFE_DIVIDE(gmv, month_gmv), 2)) AS herfindahl_index,
  1 / SUM(POW(SAFE_DIVIDE(gmv, month_gmv), 2)) AS equivalent_number_of_sellers,
  MAX(SAFE_DIVIDE(gmv, month_gmv)) AS top_seller_share
FROM (SELECT *, SUM(gmv) OVER (PARTITION BY month_start) AS month_gmv FROM m)
GROUP BY 1
ORDER BY 1;
-- equivalent_number_of_sellers = "the marketplace behaves as if it had N sellers of the same size"

-- 3) losing the buy box: same item_id sold by many sellers, share of the item views that turned into
-- a purchase from EACH seller (view_item comes with the affiliation of the offer shown)
WITH views AS (
  SELECT item_id, COALESCE(affiliation, '(not set)') AS seller, COUNT(*) AS views
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = 'view_item'
  GROUP BY 1, 2
),
sales AS (
  SELECT item_id, COALESCE(affiliation, '(not set)') AS seller, SUM(quantity) AS units, AVG(price) AS avg_price
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND is_valid_for_revenue
  GROUP BY 1, 2
),
multi_seller_items AS (
  SELECT item_id FROM sales GROUP BY 1 HAVING COUNT(DISTINCT seller) >= 2
)
SELECT
  s.item_id,
  s.seller,
  s.avg_price,
  s.units,
  COALESCE(v.views, 0) AS views_of_this_offer,
  SAFE_DIVIDE(s.units, SUM(s.units) OVER (PARTITION BY s.item_id)) AS share_of_item_units,
  SAFE_DIVIDE(s.avg_price, MIN(s.avg_price) OVER (PARTITION BY s.item_id)) - 1 AS price_above_cheapest
FROM sales AS s
JOIN multi_seller_items USING (item_id)
LEFT JOIN views AS v USING (item_id, seller)
ORDER BY s.item_id, s.units DESC;

-- 4) sellers that bring NEW customers to the marketplace (first order of the customer had the seller)
SELECT
  COALESCE(affiliation, '(not set)') AS seller,
  COUNT(DISTINCT IF(is_first_purchase, user_key, NULL)) AS new_customers_brought,
  COUNT(DISTINCT user_key) AS customers,
  SAFE_DIVIDE(COUNT(DISTINCT IF(is_first_purchase, user_key, NULL)), COUNT(DISTINCT user_key)) AS acquisition_share
FROM `your-gcp-project.ga4_core.fct_transaction_items`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  AND is_valid_for_revenue
GROUP BY 1
HAVING COUNT(DISTINCT user_key) >= 50
ORDER BY new_customers_brought DESC
LIMIT 50;
-- sellers with high acquisition_share deserve lower commission or featured slots: they grow the base
