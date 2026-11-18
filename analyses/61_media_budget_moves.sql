-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the next real of media: marginal ROAS, the split that equalizes it, and the ROAS of the people brought

-- 1) every campaign with its curve: average ROAS (what everybody sees) vs marginal ROAS (what decides)
SELECT platform, campaign, days_with_spend, avg_daily_spend, average_roas, marginal_roas_at_current_spend, target_marginal_roas,
       spend_at_target_marginal_roas, headroom_daily_spend, revenue_of_next_increment, is_reliable, recommendation
FROM `your-gcp-project.ga4_marketing.mkt_spend_response_curves`
ORDER BY is_reliable DESC, cost DESC;

-- 2) the suggested split of the SAME budget (a test plan for 2 weeks, not an autopilot)
SELECT platform, campaign, current_daily_spend, suggested_daily_spend, daily_spend_change_pct, marginal_roas_before, marginal_roas_after,
       expected_daily_revenue_change, is_at_bound, total_expected_daily_revenue_change, budget_gap
FROM `your-gcp-project.ga4_marketing.mkt_budget_reallocation`
ORDER BY daily_spend_change DESC;

-- 3) the campaigns that bring people who keep buying: ROAS D0 x D30 x D90 x D180 and the payback day
SELECT acquisition_month, campaign, main_channel, users_acquired, cost, roas_d0, roas_d30, roas_d90, roas_d180, payback_day, cost_per_new_customer
FROM `your-gcp-project.ga4_marketing.mkt_cohort_roas_by_campaign`
WHERE cost > 0
ORDER BY acquisition_month DESC, cost DESC;

-- 4) the "late bloomers": campaigns judged by day 0 that pay later (ROAS D90 / D0)
SELECT campaign, SUM(cost) AS cost, SUM(revenue_d0) / SUM(cost) AS roas_d0, SUM(revenue_d90) / SUM(cost) AS roas_d90,
  SAFE_DIVIDE(SUM(revenue_d90), SUM(revenue_d0)) AS growth_d0_to_d90
FROM `your-gcp-project.ga4_marketing.mkt_cohort_roas_by_campaign`
WHERE cost > 0 AND revenue_d90 IS NOT NULL
GROUP BY 1
HAVING SUM(cost) >= 1000
ORDER BY growth_d0_to_d90 DESC;
