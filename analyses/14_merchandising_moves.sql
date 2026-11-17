-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the weekly list for who decides what goes where in the store: products to move up or down
-- in the lists, hidden gems, products dying, who steals the sale from whom, and the reminders
-- that should go out this week.

-- 1) move in the lists (position bias removed)
SELECT item_list_name, item_name, merchandising_action, ROUND(avg_position, 1) AS avg_position,
  impressions, clicks, ROUND(coec, 2) AS clicks_over_expected, ROUND(extra_clicks_at_best_position) AS extra_clicks_at_best_position
FROM `your-gcp-project.ga4_ecommerce.ecom_list_position_bias`
WHERE merchandising_action != 'keep'
ORDER BY merchandising_action, extra_clicks_at_best_position DESC
LIMIT 100;

-- 2) hidden gems and traffic eaters, and what is rising before the revenue shows it
SELECT item_name, item_category, lifecycle_stage, opportunity, views_14d, ROUND(views_growth, 2) AS views_growth,
  ROUND(cart_rate, 3) AS cart_rate, ROUND(catalog_cart_rate, 3) AS catalog_cart_rate, revenue_28d
FROM `your-gcp-project.ga4_ecommerce.ecom_item_momentum`
WHERE opportunity != 'none' OR lifecycle_stage IN ('rising', 'declining', 'dead')
ORDER BY opportunity = 'hidden_gem' DESC, lifecycle_stage = 'rising' DESC, views_14d DESC
LIMIT 200;

-- 3) the substitute of each product (what to show when it is out of stock, or next to it)
SELECT viewed_item_name, purchased_item_name, switch_sessions, ROUND(share_of_losses, 2) AS share_of_losses,
  ROUND(loss_rate_when_seen_together, 2) AS loss_rate_when_seen_together, ROUND(price_gap_pct, 2) AS price_gap_pct, trade_direction
FROM `your-gcp-project.ga4_ecommerce.ecom_item_switching`
WHERE rank_among_substitutes <= 3
ORDER BY switch_sessions DESC
LIMIT 200;

-- 4) reminders of the week: products with a real cycle and customers inside the window
SELECT entity_name, level, median_days_between, cycle_type, suggested_reminder_day, customers_due_now, customers_overdue
FROM `your-gcp-project.ga4_ecommerce.ecom_replenishment_cycles`
WHERE cycle_type IN ('strong_cycle', 'loose_cycle')
ORDER BY customers_due_now DESC
LIMIT 50;
