-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- what really works: every lift measured, the most trustworthy evidence first

SELECT evidence_level, lift_type, name, metric, start_date, end_date,
       ROUND(100 * relative_lift, 1) AS lift_pct,
       ROUND(100 * lift_ci_low, 1) AS ci_low_pct,
       ROUND(100 * lift_ci_high, 1) AS ci_high_pct,
       p_value, incremental_value, verdict, source_table
FROM `your-gcp-project.ga4_lifts.lift_registry`
ORDER BY evidence_level, ABS(COALESCE(relative_lift, 0)) DESC;

-- behaviours worth an A/B test: strong ADJUSTED association, not a funnel step, decent coverage
SELECT event_name, coverage, purchase_rate_with, purchase_rate_without,
       naive_lift, adjusted_lift, adjusted_lift_ci_low, adjusted_lift_ci_high, confounding_ratio,
       attributable_purchases, verdict
FROM `your-gcp-project.ga4_lifts.lift_behaviors_adjusted`
WHERE NOT is_purchase_funnel_step
  AND verdict = 'positive'
ORDER BY attributable_purchases DESC
LIMIT 20;

-- one intervention, day by day (the chart): actual vs what would have happened
SELECT metric_date, period, actual, counterfactual, effect
FROM `your-gcp-project.ga4_lifts.lift_interventions_daily`
WHERE intervention_name = 'one_page_checkout_mobile'
  AND metric = 'conversion_rate'
ORDER BY metric_date;
