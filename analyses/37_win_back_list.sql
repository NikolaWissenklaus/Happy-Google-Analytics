-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the win back list: customers that HAD a rhythm and lost it.
-- a customer that used to buy every 40 days and has not bought for 120 is not "inactive for
-- 120 days", they are 3 cycles late. Sort by the money at stake, respect the consent.

WITH history AS (
  SELECT
    user_key,
    COUNT(*) AS orders,
    SUM(revenue) AS revenue,
    MAX(transaction_date) AS last_order_date,
    -- usual cycle = median days between orders of the customer
    APPROX_QUANTILES(days_since_previous_order, 2 IGNORE NULLS)[OFFSET(1)] AS usual_cycle_days,
    AVG(revenue) AS avg_order_value
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 730 DAY)
  GROUP BY user_key
  HAVING COUNT(*) >= 2
)
SELECT
  h.user_key,
  u.user_id,
  h.orders,
  h.revenue,
  h.avg_order_value,
  h.usual_cycle_days,
  h.last_order_date,
  DATE_DIFF(CURRENT_DATE(), h.last_order_date, DAY) AS days_since_last_order,
  SAFE_DIVIDE(DATE_DIFF(CURRENT_DATE(), h.last_order_date, DAY), GREATEST(h.usual_cycle_days, 7)) AS cycles_late,
  -- yearly value at stake if the customer is gone
  SAFE_DIVIDE(365, GREATEST(h.usual_cycle_days, 7)) * h.avg_order_value AS yearly_value_at_stake,
  u.last_channel,
  u.days_since_last_seen,
  u.latest_consent_ads,
  CASE
    WHEN u.days_since_last_seen <= 14 THEN 'still_visits_without_buying (price? stock? competitor?)'
    ELSE 'gone_silent'
  END AS situation
FROM history AS h
JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
WHERE SAFE_DIVIDE(DATE_DIFF(CURRENT_DATE(), h.last_order_date, DAY), GREATEST(h.usual_cycle_days, 7)) BETWEEN 2 AND 6
ORDER BY yearly_value_at_stake DESC
LIMIT 500;

-- the probabilistic version (BTYD p_alive) and the habit of visits:
-- analyses/07_who_to_call_today.sql and analyses/15_who_broke_the_habit.sql
