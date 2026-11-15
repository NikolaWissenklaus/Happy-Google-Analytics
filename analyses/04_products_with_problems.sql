-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- products that people look at and do not buy (price, shipping, stock, photo, size...),
-- sorted by the revenue they leave behind
SELECT *
FROM `your-gcp-project.ga4_ecommerce.ecom_problem_products`
ORDER BY revenue_opportunity_30d DESC
LIMIT 30;

-- products abandoned in the cart way more than their category
SELECT item_id, item_name, item_category, carts, carts_abandoned, item_abandonment_rate,
       category_abandonment_rate, abandonment_gap_vs_category
FROM `your-gcp-project.ga4_ecommerce.ecom_abandoned_cart_items`
WHERE abandonment_gap_vs_category > 0.15
ORDER BY carts_abandoned DESC
LIMIT 30;

-- did a price change move the demand? (elasticity per item)
SELECT *
FROM `your-gcp-project.ga4_ecommerce.ecom_price_elasticity`
LIMIT 30;

-- suspected stockouts: product that sold every day and suddenly has views and no sales
SELECT *
FROM `your-gcp-project.ga4_ecommerce.ecom_suspected_stockouts`
LIMIT 30;
