-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- before the A/B test: can this page detect the change you want? After it: did it work the same for everybody?

-- 1) the testing capacity of the site: what each place can detect in 2, 4 and 8 weeks
SELECT scope, target, daily_units, baseline_rate, mde_in_14_days, mde_in_28_days, mde_in_56_days,
       days_for_10pct_lift, days_for_20pct_lift, annual_value_of_1pct_lift, verdict
FROM `your-gcp-project.ga4_cro.cro_test_capacity_planner`
ORDER BY scope, daily_units DESC;

-- 2) by hand: sessions per variant to see 2.0% -> 2.2% (+10%), and the MDE of 15k sessions per variant
SELECT
  `your-gcp-project.ga4_udf.sample_size_proportions`(0.02, 0.10, 0.05, 0.8) AS sessions_per_variant_for_10pct,
  `your-gcp-project.ga4_udf.mde_proportions`(0.02, 15000, 0.05, 0.8) AS relative_mde_with_15k_per_variant,
  `your-gcp-project.ga4_udf.inverse_normal_cdf`(0.975) AS z_95,
  `your-gcp-project.ga4_udf.inverse_normal_cdf`(0.995) AS z_99;

-- 3) the tests that work differently by segment (heterogeneity), and where
SELECT experiment_id, variant_id, segment_type, segment_value, users, control_conversion_rate, conversion_rate,
       relative_uplift, q_value, heterogeneity_p_value, i_squared, segment_verdict
FROM `your-gcp-project.ga4_cro.cro_ab_test_segments`
WHERE effect_differs_by_segment_type
ORDER BY experiment_id, segment_type, relative_uplift DESC;

-- 4) the honest summary for the test owner: overall verdict next to the segments that disagree
SELECT r.experiment_id, r.variant_id, r.verdict AS overall_verdict, s.segment_type, s.segment_value, s.segment_verdict, s.relative_uplift
FROM `your-gcp-project.ga4_cro.cro_ab_test_results` AS r
JOIN `your-gcp-project.ga4_cro.cro_ab_test_segments` AS s USING (experiment_id, variant_id)
WHERE NOT r.is_control
  AND s.segment_verdict IN ('winner_here', 'loser_here')
ORDER BY 1, 2, 4;
