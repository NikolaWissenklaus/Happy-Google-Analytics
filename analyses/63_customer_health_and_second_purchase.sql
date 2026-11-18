-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- customer success for e-commerce: who is getting sick, why, and what in the first order brings people back

-- 1) the health of the base
SELECT health_band, COUNT(*) AS customers, SUM(lifetime_revenue) AS lifetime_revenue, AVG(health_score) AS avg_score
FROM `your-gcp-project.ga4_segments.seg_customer_health_score`
GROUP BY 1
ORDER BY avg_score DESC;

-- 2) the call list of the week: valuable customers at risk, with the main issue
SELECT user_key, user_id, lifetime_revenue, transactions, days_since_last_purchase, expected_gap_days, health_score, health_band, main_issue, priority
FROM `your-gcp-project.ga4_segments.seg_customer_health_score`
WHERE health_band IN ('at_risk', 'critical')
ORDER BY priority DESC
LIMIT 200;

-- 3) what costs the most points, by band (recency is the CRM, friction is the operation)
SELECT health_band, main_issue, COUNT(*) AS customers
FROM `your-gcp-project.ga4_segments.seg_customer_health_score`
GROUP BY 1, 2
ORDER BY 1, customers DESC;

-- 4) what in the first order speeds up the second one (Cox, every covariate adjusted for the others)
SELECT covariate, covariate_type, hazard_ratio, hr_low, hr_high, p_value, mean_value, interpretation, concordance, subjects, events
FROM `your-gcp-project.ga4_data_science.ds_second_purchase_cox`
ORDER BY p_value;
