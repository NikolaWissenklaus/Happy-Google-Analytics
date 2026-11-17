-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- regular users that are late for their own rhythm: the churn signal that comes weeks before
-- "30 days without a visit". The most valuable first. Join with the activation tables (consent
-- gate) before sending anything to anybody.

SELECT
  r.user_key,
  r.rhythm_type,
  r.usual_gap_days,
  r.last_active_date,
  r.expected_next_visit_date,
  r.days_late,
  r.longest_streak_days,
  ROUND(r.weekly_trend, 2) AS weekly_trend,
  r.revenue AS revenue_180d,
  u.lifetime_revenue,
  u.main_channel
FROM `your-gcp-project.ga4_segments.seg_visit_rhythm` AS r
JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
WHERE r.habit_status = 'broke_the_habit'
  AND r.rhythm_type IN ('clockwork', 'regular')
ORDER BY u.lifetime_revenue DESC
LIMIT 500;

-- the missions still open with money on the table (came to buy, did not finish, may come back)
SELECT user_key, mission_start_date, sessions, deepest_stage, channel_path, value_at_stake
FROM `your-gcp-project.ga4_data_science.ds_shopping_missions`
WHERE outcome = 'open' AND deepest_stage IN ('checkout', 'cart')
ORDER BY value_at_stake DESC
LIMIT 200;
