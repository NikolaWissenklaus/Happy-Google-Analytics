-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the monday question of CRO: which step broke, for whom, and how much money is it?

-- 1) the steps that changed last week for real (false discovery rate controlled), with the money
SELECT segment_type, segment_value, step_name, entered, rate, baseline_rate, relative_change_vs_baseline, q_value, revenue_impact, verdict
FROM `your-gcp-project.ga4_cro.cro_funnel_weekly_step_changes`
WHERE week_start = (SELECT MAX(week_start) FROM `your-gcp-project.ga4_cro.cro_funnel_weekly_step_changes`)
  AND verdict IN ('broke', 'improved')
ORDER BY ABS(revenue_impact) DESC;

-- 2) the 12 week history of one step (put it in a line chart)
SELECT week_start, segment_value AS device, rate, baseline_rate, verdict
FROM `your-gcp-project.ga4_cro.cro_funnel_weekly_step_changes`
WHERE segment_type = 'device' AND step_name = 'begin_checkout -> add_shipping_info'
ORDER BY week_start, device;

-- 3) the funnel of PEOPLE: of the new users of each week, how many reached each step in 7 and 30 days
SELECT cohort_week, step, cohort_users, reached_d0, reached_d7, reached_d30, median_days_to_step
FROM `your-gcp-project.ga4_cohorts.coh_user_funnel_by_cohort`
WHERE segment_type = 'all'
ORDER BY cohort_week DESC, step_number;

-- 4) which first channel brings people that actually buy (30 days), and how long they take
SELECT segment_value AS first_channel, SUM(cohort_users) AS users,
  SUM(reached_d30 * cohort_users) / SUM(IF(reached_d30 IS NULL, 0, cohort_users)) AS bought_within_30_days,
  APPROX_QUANTILES(median_days_to_step, 2 IGNORE NULLS)[OFFSET(1)] AS typical_days_to_buy
FROM `your-gcp-project.ga4_cohorts.coh_user_funnel_by_cohort`
WHERE segment_type = 'first_channel' AND step = 'purchase'
GROUP BY 1
HAVING SUM(cohort_users) >= 500
ORDER BY bought_within_30_days DESC;
