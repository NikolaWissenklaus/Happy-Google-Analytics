-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- "conversion went from 2.1% to 2.4%, we won!" ... did we? the UDFs of ga4_udf answer that
-- in one line. Change the numbers and run.

SELECT
  -- 95% interval of each rate (Wilson, works with small numbers too)
  `your-gcp-project.ga4_udf.wilson_interval`(420, 20000, 1.96) AS before_interval,
  `your-gcp-project.ga4_udf.wilson_interval`(480, 20000, 1.96) AS after_interval,

  -- z-test of two proportions: p_value < 0.05 = probably real
  `your-gcp-project.ga4_udf.z_test_proportions`(420, 20000, 480, 20000) AS z_test,

  -- bayesian: probability that "after" is really better than "before".
  -- takes the Beta posteriors: alpha = conversions + 1, beta = non conversions + 1
  `your-gcp-project.ga4_udf.prob_b_beats_a`(420 + 1, 20000 - 420 + 1, 480 + 1, 20000 - 480 + 1) AS prob_after_is_better;

-- revenue per user is not a proportion: Welch t-test with mean, VARIANCE and n of each group
SELECT `your-gcp-project.ga4_udf.welch_t_test`(12.4, POW(55.0, 2), 20000, 13.1, POW(58.0, 2), 20000) AS revenue_per_user_test;

-- A/B tests registered in cfg_experiments.js already have all of this ready (and the SRM check)
SELECT experiment_id, variant_id, is_control, users, conversions, conversion_rate, conversion_ci_low, conversion_ci_high,
       conversion_uplift, p_value, prob_beats_control, revenue_per_user_uplift, srm_p_value, verdict
FROM `your-gcp-project.ga4_cro.cro_ab_test_results`
ORDER BY experiment_id, variant_id;
