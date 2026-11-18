-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: beauty, pet, pharmacy, supplements, grocery, coffee, baby (products that END)
-- the customer will buy again, the only question is where. The store that reminds at the right
-- day keeps the customer; a subscription offer to the regulars locks them.

-- 1) repurchase cycle per product (same customer, same item, consecutive orders)
WITH purchases AS (
  SELECT user_key, item_id, ANY_VALUE(item_name) AS item_name, transaction_date
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY)
  GROUP BY user_key, item_id, transaction_date
),
gaps AS (
  SELECT *, DATE_DIFF(transaction_date, LAG(transaction_date) OVER (PARTITION BY user_key, item_id ORDER BY transaction_date), DAY) AS gap_days
  FROM purchases
),
cycles AS (
  SELECT
    item_id,
    ANY_VALUE(item_name) AS item_name,
    COUNT(DISTINCT user_key) AS buyers,
    COUNT(DISTINCT IF(gap_days IS NOT NULL, user_key, NULL)) AS repeat_buyers,
    APPROX_QUANTILES(gap_days, 100 IGNORE NULLS)[OFFSET(50)] AS median_cycle_days,
    APPROX_QUANTILES(gap_days, 100 IGNORE NULLS)[OFFSET(25)] AS p25_cycle_days,
    APPROX_QUANTILES(gap_days, 100 IGNORE NULLS)[OFFSET(75)] AS p75_cycle_days
  FROM gaps
  GROUP BY item_id
)
SELECT *, SAFE_DIVIDE(repeat_buyers, buyers) AS same_item_repeat_rate
FROM cycles
WHERE repeat_buyers >= 10
ORDER BY repeat_buyers DESC;

-- 2) who is DUE this week: last purchase of the item + median cycle of the item falls in the next 7 days
WITH purchases AS (
  SELECT user_key, item_id, ANY_VALUE(item_name) AS item_name, MAX(transaction_date) AS last_bought,
         COUNT(DISTINCT transaction_id) AS times_bought
  FROM `your-gcp-project.ga4_core.fct_transaction_items`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY)
  GROUP BY user_key, item_id
),
cycles AS (
  SELECT item_id, APPROX_QUANTILES(gap, 2 IGNORE NULLS)[OFFSET(1)] AS median_cycle_days, COUNT(gap) AS gaps
  FROM (
    SELECT item_id, DATE_DIFF(transaction_date, LAG(transaction_date) OVER (PARTITION BY user_key, item_id ORDER BY transaction_date), DAY) AS gap
    FROM (SELECT DISTINCT user_key, item_id, transaction_date
          FROM `your-gcp-project.ga4_core.fct_transaction_items`
          WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY))
  )
  GROUP BY item_id
  HAVING COUNT(gap) >= 10
)
SELECT
  p.user_key, u.user_id, p.item_id, p.item_name, p.times_bought, p.last_bought, c.median_cycle_days,
  DATE_ADD(p.last_bought, INTERVAL c.median_cycle_days DAY) AS expected_next_purchase,
  u.latest_consent_ads
FROM purchases AS p
JOIN cycles AS c USING (item_id)
JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
WHERE DATE_ADD(p.last_bought, INTERVAL c.median_cycle_days DAY) BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY p.times_bought DESC, expected_next_purchase;

-- 3) subscription candidates: bought the same item 3+ times with a regular cycle
-- (coefficient of variation of the gaps below 0.35 = a metronome, offer "assine e economize")
SELECT
  user_key, item_id, COUNT(*) AS purchases, AVG(gap) AS avg_cycle_days,
  SAFE_DIVIDE(STDDEV(gap), AVG(gap)) AS cycle_cv
FROM (
  SELECT user_key, item_id,
    DATE_DIFF(transaction_date, LAG(transaction_date) OVER (PARTITION BY user_key, item_id ORDER BY transaction_date), DAY) AS gap
  FROM (SELECT DISTINCT user_key, item_id, transaction_date
        FROM `your-gcp-project.ga4_core.fct_transaction_items`
        WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY))
)
WHERE gap IS NOT NULL
GROUP BY user_key, item_id
HAVING COUNT(*) >= 2 AND SAFE_DIVIDE(STDDEV(gap), AVG(gap)) < 0.35
ORDER BY purchases DESC
LIMIT 500;

-- the model version (categories, due windows): ga4_ecommerce.ecom_replenishment_cycles
